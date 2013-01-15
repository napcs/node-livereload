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

# Options

The `createServer()` method supports a few basic options, passed as a JavaScript object:

* `port` is the listening port. It defaults to `35729` which is what the LiveReload extensions use currently.
* `exts` is an array of extensions you want to observe. The default extensions are  `html`, `css`, `js`, `png`, `gif`, `jpg`,
  `php`, `php5`, `py`, `rb`, and `erb`
* `applyJSLive` tells LiveReload to reload JavaScript files in the background instead of reloading the page. The default for this is `false`.
* `applyCSSLive` tells LiveReload to reload CSS files in the background instead of refreshing the page. The default for this is `true`.
* `exclusions` lets you specify files to ignore. By default, this includes `.git/`, `.svn/`, and `.hg/`
* `alias` lets you specify file extensions to be aliased. By default, this maps `.styl` to `.css`, by which, changing `.styl` file never fires full page reload.

# Limitations

Right now this is extremely simple. It relies on polling so there's a delay in refreshing the browser. It could be faster.

# License

Copyright (c) 2010-2012 Joshua Peek and Brian P. Hogan.

Released under the MIT license. See `LICENSE` for details.

