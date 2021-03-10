const fs               = require('fs');
const path             = require('path');
const ws               = require('ws');
const http             = require('http');
const https            = require('https');
const url              = require('url');
const chokidar         = require('chokidar');
const EventEmitter     = require('events');


// Server accepts a Configuration object to configure the server.
//
// `version`: The protocol version to use.
// `port`: the LiveReload listen port
// `exts`: the extensions to watch. An array of extensions.
// `extraExts`: extensions in addition to the default extensions
// `exclusions`: array of regex patterns to exclude. Default is [/\.git\//, /\.svn\//, /\.hg\//]
// `filesToReload`: array of files that, when changed, should force the browser to reload
// `applyCSSLive`: should the css apply live? Default is true
// `originalPath`: the original path. Useful for proxy
// `usePolling`: Should we use polling instead of a file watcher? defaults to false.
// `delay`: seconds to wait
// `debug`: display debug mesages to stdout. Default is false
//
class Server extends EventEmitter {
  constructor(config) {
    super();

    const protocol_version = '7';
    const defaultPort      = 35729;

    const defaultExts = [
      'html', 'css', 'js', 'png', 'gif', 'jpg',
      'php', 'php5', 'py', 'rb', 'erb', 'coffee'
    ];

    const defaultExclusions = [/\.git\//, /\.svn\//, /\.hg\//];

    this.config = config;

    if (this.config               == null) { this.config = {}; }
    if (this.config.version       == null) { this.config.version = protocol_version; }
    if (this.config.port          == null) { this.config.port = defaultPort; }
    if (this.config.exts          == null) { this.config.exts = []; }
    if (this.config.extraExts     == null) { this.config.extraExts = []; }
    if (this.config.exclusions    == null) { this.config.exclusions = []; }
    if (this.config.filesToReload == null) { this.config.filesToReload = []; }
    if (this.config.applyCSSLive  == null) { this.config.applyCSSLive = true; }
    if (this.config.originalPath  == null) { this.config.originalPath = ''; }
    if (this.config.overrideURL   == null) { this.config.overrideURL = ''; }
    if (this.config.usePolling    == null) { this.config.usePolling = false; }
    if (this.config.exts.length   === 0)   { this.config.exts = defaultExts; }

    if (this.config.extraExts.length > 0) {
      this.config.exts = this.config.extraExts.concat(defaultExts);
    }

    this.config.exclusions = this.config.exclusions.concat(defaultExclusions);

  }

  listen(callback) {
    this.debug("LiveReload is waiting for a browser to connect...");
    this.debug(`\
Protocol version: ${this.config.version}
Exclusions: ${this.config.exclusions}
Extensions: ${this.config.exts}
Polling: ${this.config.usePolling}
\
`
    );

    if (this.config.server) {
      this.config.server.listen(this.config.port);
      this.server = new ws.Server({server: this.config.server});
    } else {
      this.server = new ws.Server({port: this.config.port});
    }

    this.server.on('connection', this.onConnection.bind(this));
    this.server.on('close',      this.onClose.bind(this));
    this.server.on('error',      this.onError.bind(this));

    if (callback) {
      this.server.once('listening', callback);
    }
  }

  // Bubble up the connection error to the parent process
  // Subscribe with server.on "error"
  onError(err) {
      this.debug(`Error ${err}`);
      this.emit("error", err);
    }


  // Client sends various messages under the key 'command'
  //
  // 'hello': the handshake. Must reply with 'hello'
  // 'info' : info about the client script and any plugins it has enabled
  //
  onConnection(socket) {
    this.debug("Browser connected.");

    socket.on('message', message => {
      this.debug(`Client message: ${message}`);

      const request = JSON.parse(message);

      if (request.command === "hello") {
        this.debug("Client requested handshake...");
        this.debug(`Handshaking with client using protocol ${this.config.version}...`);

        const data = JSON.stringify({
          command: 'hello',
          protocols: [
              'http://livereload.com/protocols/official-7',
              'http://livereload.com/protocols/official-8',
              'http://livereload.com/protocols/official-9',
              'http://livereload.com/protocols/2.x-origin-version-negotiation',
              'http://livereload.com/protocols/2.x-remote-control'],
          serverName: 'node-livereload'
        });

        socket.send(data);
      }

      // info messages are messages about the features the client server has, like
      // plugins. We don't support these but in debug mode we should at least
      // acknowledge them in the console for debugging purposes
      if (request.command === "info") {
        this.debug("Server received client data. Not sending response.");
      }
    });

    // handle error events from socket
    socket.on('error', err => {
      this.debug(`Error in client socket: ${err}`);
    });

    socket.on('close', message => {
      this.debug("Client closed connection");
    });
  }

  onClose(socket) {
    this.debug("Socket closed.");
  }

  watch(paths) {
    this.debug(`Watching ${paths}...`);
    this.watcher = chokidar.watch(paths, {
      ignoreInitial : true,
      ignored       : this.config.exclusions,
      usePolling    : this.config.usePolling
    })
    .on('add',    this.filterRefresh.bind(this))
    .on('change', this.filterRefresh.bind(this))
    .on('unlink', this.filterRefresh.bind(this));
  }

  // Determine whether or not the file should trigger a reload.
  // Only reload if the changed file is in the list of extensions,
  // or if it's in the list of explicit file names.
  filterRefresh(filepath) {

    let refresh = false;

    this.debug(`Saw change to ${filepath}`);

    // get just the extension              without the .
    const fileext = path.extname(filepath).substring(1);

    // get the filename from the path
    const filename = path.basename(filepath);

    // check if file extension is supposed to be watched
    if (this.config.exts.indexOf(fileext) !== -1) {
      refresh = true;
    }

    // check to see if the file is explicitly listed
    if (this.config.filesToReload.indexOf(filename) !== -1) {
      refresh = true;
    }

    if (refresh) {
      if (this.config.delay) {
        let delayedRefresh;
        delayedRefresh = setTimeout( () => {
            clearTimeout(delayedRefresh);
            this.refresh(filepath);
          },
          this.config.delay
        );
      } else {
        this.refresh(filepath);
      }
    }
  }

  refresh(filepath) {
    this.debug(`Reloading: ${filepath}`);

    const data = JSON.stringify({
      command      : 'reload',
      path         : filepath,
      liveCSS      : this.config.applyCSSLive,
      liveImg      : this.config.applyImgLive,
      originalPath : this.config.originalPath,
      overrideURL  : this.config.overrideURL
    });

    this.sendAllClients(data);
  }

  alert(message) {
    this.debug(`Alert: ${message}`);
    const data = JSON.stringify({
      command: 'alert',
      message
    });
    this.sendAllClients(data);
  }

  sendAllClients(data) {
    this.server.clients.forEach(socket => {
      this.debug(`broadcasting to all clients: ${data}`);
      socket.send(data, error => {
        if (error) {
          this.debug(error);
        }
      });
    });
  }

  debug(str) {
    if (this.config.debug) {
      console.log(`${str}\n`);
    }
  }

  close() {
    if (this.watcher) {
      this.watcher.close();
    }
    // ensure ws server is closed
    this.server._server.close();
    this.server.close();
  }
}

exports.createServer = function(config, callback) {
  let app;

  if (config == null) { config = {}; }

  const requestHandler = function( req, res ){
    if (url.parse(req.url).pathname === '/livereload.js') {
      res.writeHead(200, {'Content-Type': 'text/javascript'});
      return res.end(fs.readFileSync(require.resolve('livereload-js')));
    }
  };

  if ((config.https == null)) {
    app = http.createServer(requestHandler);
  } else {
    app = https.createServer(config.https, requestHandler);
  }

  if (config.server == null) { config.server = app; }

  const server = new Server(config);

  if (!config.noListen) {
    server.listen(callback);
  }
  return server;
};

