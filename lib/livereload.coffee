fs   = require 'fs'
path = require 'path'
ws   = require 'ws'
http  = require 'http'
https = require 'https'
url = require 'url'
chokidar = require 'chokidar'

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

    @config.usePolling ?= false

    @config.wait ?= 0
    @config.delay = @config.wait

  listen: ->
    @debug "LiveReload is waiting for browser to connect."

    if @config.server
      @config.server.listen @config.port
      @server = new ws.Server({server: @config.server})
    else
      @server = new ws.Server({port: @config.port})

    @server.on 'connection', @onConnection.bind @
    @server.on 'close',      @onClose.bind @

  onConnection: (socket) ->
    @debug "Browser connected."

    socket.send "!!ver:#{@config.version}"

    socket.on 'message', (message) =>
      if (@config.debug)
        @debug "Browser URL: #{message}"

    # FIXME: This doesn't seem to be firing either.
    socket.on 'error', (err) =>
      @debug "Error in client socket: #{err}"


  # FIXME: This does not seem to be firing
  onClose: (socket) ->
    @debug "Browser disconnected."

  watch: (paths) ->
    @watcher = chokidar.watch(paths,
      ignoreInitial: true
      ignored: @config.exclusions
      usePolling: @config.usePolling
    )
    .on 'add', @filterRefresh.bind(@)
    .on 'change', @filterRefresh.bind(@)
    .on 'unlink', @filterRefresh.bind(@)


  filterRefresh: (filepath) ->
    exts = @config.exts
    fileext = path.extname filepath
                  .substring 1

    # check if file extension is supposed to be watched
    if (exts.indexOf(fileext) != -1)
      if @config.delay
        delayedRefresh = setTimeout(
          =>
            clearTimeout(delayedRefresh)
            @refresh filepath
          @config.delay
        )
      else
        @refresh filepath

  refresh: (filepath) ->
    @debug "Refresh: #{filepath}"
    data = JSON.stringify ['refresh',
      path: filepath,
      apply_js_live: @config.applyJSLive,
      apply_css_live: @config.applyCSSLive,
      apply_img_live: @config.applyImgLive,
      original_path: this.config.originalPath,
      override_url: this.config.overrideURL
    ]

    for socket in @server.clients
      socket.send data, (error) =>
        if error
          @debug error

  debug: (str) ->
    if @config.debug
      console.log "#{str}\n"

  close: ->
    @watcher.close()
    # ensure ws server is closed
    @server._server.close()
    @server.close()

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
