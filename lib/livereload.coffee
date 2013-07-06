fs   = require 'fs'
path = require 'path'
ws   = require 'websocket.io'
http  = require 'http'
url = require 'url'

version = '1.6'
defaultPort = 35729

defaultExts = [
  'html', 'css', 'js', 'png', 'gif', 'jpg',
  'php', 'php5', 'py', 'rb', 'erb'
]

defaultExclusions = [/\.git\//, /\.svn\//, /\.hg\//]

class Server
  constructor: (@config) ->
    @config ?= {}

    @config.version ?= version
    @config.port    ?= defaultPort

    @config.exts       ?= []
    @config.exclusions ?= []

    @config.exts       = @config.exts.concat defaultExts
    @config.exclusions = @config.exclusions.concat defaultExclusions

    @config.applyJSLive  ?= false
    @config.applyCSSLive ?= true

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
              for ext in exts when filename.match "\.#{ext}$"
                callback err, filename
                break

    walk dirname, callback

  watch: (dirname) ->
    @walkTree dirname, (err, filename) =>
      throw err if err
      fs.watch filename, (event, fname) =>
        @refresh filename

  refresh: (path) ->
    @debug "Refresh: #{path}"
    data = JSON.stringify ['refresh',
      path: path,
      apply_js_live: @config.applyJSLive,
      apply_css_live: @config.applyCSSLive
    ]

    for socket in @sockets
      try
        socket.send data
      catch  # ignore socket errors and keep going...
        null

  debug: (str) ->
    if @config.debug
      console.log "#{str}\n"

exports.createServer = (config = {}) ->
  app = http.createServer ( req, res )->
    if url.parse(req.url).pathname is '/livereload.js'
      res.writeHead(200, {'Content-Type': 'text/javascript'})
      res.end fs.readFileSync __dirname + '/../ext/livereload.js'

  config.server ?= app

  server = new Server config
  server.listen()
  server
