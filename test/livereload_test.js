const livereload = require('../lib/livereload');
const should = require('should');
const request = require('request');
const http = require('http');
const url = require('url');
const fs = require('fs');
const path = require('path');
const WebSocket = require('ws');
const sinon = require('sinon');

describe('livereload config', function() {

  it('should remove default exts when provided new exts', function(done) {
    var server = livereload.createServer({ port: 35729, exts: ["html"]}, function() {
      server.close();
      return done();
    });
    server.config.exts.should.eql(["html"]);
  });

  it('should incldue default exts when provided extraExts', function(done) {
    var server = livereload.createServer({ port: 35729, extraExts: ["foobar"]}, function() {
      server.close();
      return done();
    });

    const extensionsList = [
      'foobar',
      'html', 'css', 'js', 'png', 'gif', 'jpg',
      'php', 'php5', 'py', 'rb', 'erb', 'coffee'
    ];
    server.config.exts.should.eql(extensionsList);
  });

  it('extraExts must override exts if both are given', function(done) {
    var server = livereload.createServer({ port: 35729, exts: ["md"], extraExts: ["foobar"]}, function() {
      server.close();
      return done();
    });

    const extensionsList = [
      'foobar',
      'html', 'css', 'js', 'png', 'gif', 'jpg',
      'php', 'php5', 'py', 'rb', 'erb', 'coffee'
    ];
    server.config.exts.should.eql(extensionsList);
  });

  it('should support filesToReload', function(done) {
    var server = livereload.createServer({ port: 35729, filesToReload: ["index.html"]}, function() {
      server.close();
      return done();
    });
    server.config.filesToReload.should.eql(["index.html"]);
  });
});

describe('livereload http file serving', function() {

  it('should serve up livereload.js', function(done) {
    const server = livereload.createServer({port: 35729});

    const fileContents = fs.readFileSync('./node_modules/livereload-js/dist/livereload.js').toString();

    request('http://localhost:35729/livereload.js?snipver=1', function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.equal(200);
      fileContents.should.equal(body);

      server.config.server.close();

      return done();
    });
  });

  it('should connect to the websocket server', function(done) {
    const server = livereload.createServer({port: 35729});

    const ws = new WebSocket('ws://localhost:35729/livereload');

    ws.on('open', function() {
      const data = JSON.stringify({
        command: 'hello',
        protocols: [
            'http://livereload.com/protocols/official-7',
            'http://livereload.com/protocols/official-8',
            'http://livereload.com/protocols/2.x-origin-version-negotiation']
        });
      ws.send(data);
    });
    ws.on('message', function(data, flags) {
      console.log("hello");

      data.should.equal(JSON.stringify({
          command: 'hello',
          protocols: [
              'http://livereload.com/protocols/official-7',
              'http://livereload.com/protocols/official-8',
              'http://livereload.com/protocols/official-9',
              'http://livereload.com/protocols/2.x-origin-version-negotiation',
              'http://livereload.com/protocols/2.x-remote-control'],
          serverName: 'node-livereload'

      }));

      server.config.server.close();
      ws.close();
      return done();
    });
  });

  it('should allow you to override the internal http server', function(done) {
    const app = http.createServer(function(req, res) {
      if (url.parse(req.url).pathname === '/livereload.js') {
        res.writeHead(200, {'Content-Type': 'text/javascript'});
        res.end('// nothing to see here');
      }
    });

    const server = livereload.createServer({port: 35729, server: app});

    request('http://localhost:35729/livereload.js?snipver=1', function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.equal(200);
      body.should.equal('// nothing to see here');

      server.config.server.close();

      return done();
    });
  });

  it('should allow you to specify ssl certificates to run via https', function(done){
    const server = livereload.createServer({
      port: 35729,
      https: {
        cert: fs.readFileSync(path.join(__dirname, 'ssl/localhost.cert')),
        key: fs.readFileSync(path.join(__dirname, 'ssl/localhost.key'))
      }
    });

    const fileContents = fs.readFileSync('./node_modules/livereload-js/dist/livereload.js').toString();

    // allow us to use our self-signed cert for testing
    const unsafeRequest = request.defaults({
      strictSSL: false,
      rejectUnauthorized: false
    });

    unsafeRequest('https://localhost:35729/livereload.js?snipver=1', function(error, response, body) {
      should.not.exist(error);
      response.statusCode.should.equal(200);
      fileContents.should.equal(body);

      server.config.server.close();

      return done();
    });
  });

  it('should support passing a callback to the websocket server', function(done) {
    let server;
    return server = livereload.createServer({port: 35729}, function() {
      server.config.server.close();
      return done();
    });
  });
});

describe('livereload server startup', function() {
  let server = undefined;
  let new_server = undefined;
  beforeEach(function(done) {
    server = livereload.createServer({port: 35729, debug: false});
    setTimeout(done, 2000);
  });

  afterEach(function(done) {
    server.close();
    new_server.close();
    server = undefined;
    new_server = undefined;
    return done();
  });

  it('should gracefully handle something running on the same port', function(done) {
    new_server = livereload.createServer({debug: false, port: 35729});
    new_server.on('error', err => err.code.should.be.equal("EADDRINUSE"));

    return done();
  });
});


describe('livereload file watching', function() {
  describe("file watching behavior", function() {
    let cssFile, extraFile, refresh, server, specificFile;
    let jsFile = (cssFile = (specificFile = (extraFile = (server = (refresh = undefined)))));

    beforeEach(function(done) {
      jsFile = path.join(__dirname, "tmpfile.js");
      cssFile = path.join(__dirname, "tmpfile.css");
      specificFile = path.join(__dirname, "tmpfile");
      extraFile = path.join(__dirname, "tmpfile.ex");
      fs.writeFileSync(jsFile, "use strict;", "utf-8");
      fs.writeFileSync(cssFile, "/* some css */");
      fs.writeFileSync(specificFile, "watch me");
      // ample time for files to have been written in between tests
      setTimeout(done, 1000);
    });


    afterEach(function(done) {
      server.close();
      server = undefined;
      // ample time for chokidar process to die in between tests
      setTimeout(done, 1000);
    });

    after(function() {
      fs.unlinkSync(jsFile);
      fs.unlinkSync(cssFile);
      fs.unlinkSync(specificFile);
      fs.unlinkSync(extraFile);
    });

    describe("with no extensions specified, so defaults are used", function() {

      beforeEach(function(done) {
        server = livereload.createServer({port: 22345});
        refresh = sinon.spy(server, "refresh");
        server.watch(__dirname);
        server.watcher.on('ready', done);
      });

      it("reloads js file", function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(jsFile, "use strict; var a = 1;", "utf-8");

        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 500);
      });

      it("reloads css file", function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(cssFile, "");

        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 500);
      });
    });

    describe("with default exts overridden", function() {
      beforeEach(function(done) {
        server = livereload.createServer({exts: ["js"], port: 22345});
        refresh = sinon.spy(server, "refresh");
        server.watch(__dirname);
        server.watcher.on('ready', done);
      });

      it("reloads js file", function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(jsFile, "use strict; var a = 1;", "utf-8");

        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 500);
      });

      it("does not reload css file", function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(cssFile, "");

        setTimeout(function() {
          refresh.callCount.should.be.exactly(0);
          return done();
        }
        , 500);
      });
    });

    describe("with extraexts added", function() {
      beforeEach(function(done) {
        server = livereload.createServer({extraExts: ["ex"], port: 22345});
        refresh = sinon.spy(server, "refresh");
        server.watch(__dirname);
        server.watcher.on('ready', done);
      });

      it("reloads the ex file", function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(extraFile, "use strict; var a = 1;", "utf-8");

        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 500);
      });

      it("still reloads js file", function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(jsFile, "use strict; var a = 1;", "utf-8");

        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 500);
      });
    });

    describe("with filesToReload specified", function() {
      beforeEach(function(done) {
        server = livereload.createServer({filesToReload: ["tmpfile"], port: 22345});
        refresh = sinon.spy(server, "refresh");
        server.watch(__dirname);
        server.watcher.on('ready', done);
      });

      it("reloads specific file", function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(specificFile, "testing");

        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 500);
      });

      it("still reloads js file", function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(jsFile, "use strict; var a = 1;", "utf-8");

        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 500);
      });
    });
  });

  describe("config.delay", function() {
    let clock, refresh, server, tmpFile2;
    let tmpFile = (tmpFile2 = (clock = (server = (refresh = undefined))));

    beforeEach(function(done) {
      tmpFile = path.join(__dirname, "tmpfile.js");
      tmpFile2 = path.join(__dirname, "tmpfile2.js");
      fs.writeFileSync(tmpFile, "use strict;", "utf-8");
      fs.writeFileSync(tmpFile2, "use strict;", "utf-8");
      // ample time for files to have been written in between tests
      setTimeout(done, 1000);
    });


    afterEach(function(done) {
      server.close();
      server = undefined;
      // ample time for chokidar process to die in between tests
      setTimeout(done, 1000);
    });

    after(function() {
      fs.unlinkSync(tmpFile);
      fs.unlinkSync(tmpFile2);

      it('should send a refresh message near immediately if `config.delay` is falsey`', function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(tmpFile, "use strict; var a = 1;", "utf-8");

        // still called after next tick, but without artificial delay
        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 500);
      });
    });

    describe('when set', function() {
      beforeEach(function(done) {
        server = livereload.createServer({delay: 2000, port: 12345});
        refresh = sinon.spy(server, "refresh");
        server.watch(__dirname);
        server.watcher.on('ready', done);
      });

      it('should send a refresh message after `config.delay` milliseconds', function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(tmpFile, "use strict; var a = 1;", "utf-8");

        // not called yet
        setTimeout(() => refresh.callCount.should.be.exactly(0)
        , 1500);

        // called after set delay
        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 3000);
      });

      it('should only set the timeout/refresh for files that have been changed', function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(tmpFile2, "use strict; var a = 2;", "utf-8");

        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 3000);
      });
    });

    describe('when not set or set to 0', function() {
      beforeEach(function(done) {
        server = livereload.createServer({delay: 0, port: 22345});
        refresh = sinon.spy(server, "refresh");
        server.watch(__dirname);
        server.watcher.on('ready', done);
      });

      return it('should send a refresh message near immediately if `config.delay` is falsey`', function(done) {
        refresh.callCount.should.be.exactly(0);
        fs.writeFileSync(tmpFile, "use strict; var a = 1;", "utf-8");

        // still called after next tick, but without artificial delay
        setTimeout(function() {
          refresh.callCount.should.be.exactly(1);
          return done();
        }
        , 500);
      });
    });
  });


  it('should correctly ignore common exclusions', function() {});
    // TODO check it ignores common exclusions

  it('should not exclude a dir named git', function() {});
});
    // cf. issue #20
