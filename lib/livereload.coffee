fs   = require 'fs'
path = require 'path'
ws   = require 'websocket.io'
http  = require 'http'
https = require 'https'
url = require 'url'

protocol_version = '1.6'
defaultPort = 35729

defaultExts = [
  'html', 'css', 'js', 'png', 'gif', 'jpg',
  'php', 'php5', 'py', 'rb', 'erb', 'coffee'
]

defaultExclusions = [/\\.git\//, /\\.svn\//, /\\.hg\//]

class Server
  constructor: (@config) ->
    @config ?= {}

    @config.version ?= protocol_version
    @config.port    ?= defaultPort

    @config.exts       ?= []
    @config.exclusions ?= []

    @config.exts       = @config.exts.concat defaultExts
    @config.exclusions = @config.exclusions.concat defaultExclusions

    @config.applyJSLive  ?= false
    @config.applyCSSLive ?= true
    @config.applyImgLive ?= true

    @config.originalPath ?= ''
    @config.overrideURL ?= ''

    @config.interval ?= 1000

    @sockets = []

  listen: ->
    @debug "LiveReload is waiting for browser to connect."

    if @config.server
      @config.server.listen @config.port
      @server = ws.attach(@config.server)
    else
      @server = ws.listen(@config.port)

    @server.on 'connection', @onConnection.bind @
    @server.on 'close',      @onClose.bind @


  onConnection: (socket) ->
    @debug "Browser connected."
    socket.send "!!ver:#{@config.version}"

    socket.on 'message', (message) =>
      @debug "Browser URL: #{message}"
    socket.on 'error', (err) =>
      @debug "Error in client socket: #{err}"

    @sockets.push socket

  onClose: (socket) ->
    @debug "Browser disconnected."

  walkTree: (dirname, callback) ->
    exts       = @config.exts
    exclusions = @config.exclusions

    walk = (dirname) ->
      fs.readdir dirname, (err, files) ->
        if err then return callback err

        files.forEach (file) ->
          filename = path.join dirname, file

          for exclusion in exclusions
            return if filename.match exclusion

          fs.stat filename, (err, stats) ->
            if !err and stats.isDirectory()
              walk filename
            else
              for ext in exts when filename.match "\\.#{ext}$"
                callback err, filename
                break

    walk dirname, callback

  watch: (dirname) ->
    dirname = [dirname] if typeof dirname is "string"

    dirname.forEach (dir) =>
      @walkTree dir, (err, filename) =>
        throw err if err

        if @config.fast
          watcher = null
          handler = () =>
            if watcher
              watcher.close()
              @refresh filename
            watcher = fs.watch filename, {persistent: false}, handler
          handler()
        else
          fs.watchFile filename, {interval: @config.interval}, (curr, prev) =>
            @refresh filename if curr.mtime > prev.mtime

  refresh: (path) ->
    @debug "Refresh: #{path}"
    data = JSON.stringify ['refresh',
      path: path,
      apply_js_live: @config.applyJSLive,
      apply_css_live: @config.applyCSSLive,
      apply_img_live: @config.applyImgLive,
      original_path: this.config.originalPath,
      override_url: this.config.overrideURL
    ]

    for socket in @sockets
      socket.send data

  debug: (str) ->
    if @config.debug
      console.log "#{str}\n"

exports.createServer = (config = {}) ->
  requestHandler = ( req, res )->
    if url.parse(req.url).pathname is '/livereload.js'
      res.writeHead(200, {'Content-Type': 'text/javascript'})
      res.end fs.readFileSync __dirname + '/../ext/livereload.js'
  if !config.https?
    app = http.createServer requestHandler
  else
    app = https.createServer config.https, requestHandler

  config.server ?= app

  server = new Server config
  server.listen()
  server
