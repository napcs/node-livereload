
node-livereload
===============

An implementation of the LiveReload server in Node.js. It's an alternative to the graphical [http://livereload.com/](http://livereload.com/) application, which monitors files for changes and reloads your web browser.

# Example Usage

First, install the LiveReload browser plugins by visiting [http://help.livereload.com/kb/general-use/browser-extensions](http://help.livereload.com/kb/general-use/browser-extensions).

To use livereload from the command line:

    $ npm install -g livereload
    $ livereload [path]


Or to use the api within a project:

    $ npm install livereload

Then, simply create a server and fire it up.

    livereload = require('livereload');
    server = livereload.createServer();
    server.watch(__dirname + "/public");

You can also use this with a Connect server:

    connect = require('connect');
    connect.createServer(
      connect.compiler({ src: __dirname + "/public", enable: ['less'] }),
      connect.staticProvider(__dirname + "/public")
    ).listen(3000);

    livereload = require('livereload');
    server = livereload.createServer({exts: ['less']});
    server.watch(__dirname + "/public");

Watching multiple paths:

Passing an array of paths will allow you to watch multiple directories. All directories have the same configuration options.

```js
server.watch([__dirname + "/js", __dirname + "/css"]);
```

Using originalPath option:

```js
// server.js
var server = livereload.createServer({
    originalPath: "http://domain.com"
});
server.watch('/User/Workspace/test');
```

`$ node server.js`

```html
<!-- html -->
<head>
    <link rel="stylesheet" href="http://domain.com/css/style.css">
</head>
```

When `/User/Workspace/test/css/style.css` modified, the stylesheet will be reload.

# Command-line Options

The commandline options are

* `-p` or `--port` to specify the listening port
* `-i` or `--interval` to specify the listening interval in milliseconds. Default is 1000.
* `-f` or `--fast` to use [fs.watch](https://nodejs.org/docs/latest/api/fs.html#fs_fs_watch_filename_options_listener)
  for nearly instant refreshes.  Doesn't work on network filesystems.

Specify the path when using the options.

~~~
$ livereload . -i 200
~~~


# API Options

The `createServer()` method supports a few basic options, passed as a JavaScript object:

* `https` is an optional object of options to be passed to [https.createServer](http://nodejs.org/api/https.html#https_https_createserver_options_requestlistener) (if not provided, `http.createServer` is used instead)
* `port` is the listening port. It defaults to `35729` which is what the LiveReload extensions use currently.
* `fast` is an optional boolean.  Set to true to use `fs.watch` for faster refreshes for most filesystems.
* `exts` is an array of extensions you want to observe. The default extensions are  `html`, `css`, `js`, `png`, `gif`, `jpg`,
  `php`, `php5`, `py`, `rb`,  `erb`, and "coffee."
* `applyJSLive` tells LiveReload to reload JavaScript files in the background instead of reloading the page. The default for this is `false`.
* `applyCSSLive` tells LiveReload to reload CSS files in the background instead of refreshing the page. The default for this is `true`.
* `exclusions` lets you specify files to ignore. By default, this includes `.git/`, `.svn/`, and `.hg/`
* `originalPath` Set URL you use for development, e.g 'http:/domain.com', then LiveReload will proxy this url to local path.
* `overrideURL` override the stylesheet href with your set.

# Limitations

Right now this is extremely simple. It relies on polling so there's a delay in refreshing the browser, unless the
fast option is used (which has [caveats](https://nodejs.org/docs/latest/api/fs.html#fs_caveats)).

# License

Copyright (c) 2010-2014 Brian P. Hogan and Joshua Peek

Released under the MIT license. See `LICENSE` for details.
