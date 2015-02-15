livereload = require '../lib/livereload'
proxyquire = require 'proxyquire'
should = require 'should'
request = require 'request'
tmp = require 'tmp'
http = require 'http'
url = require 'url'
fs = require 'fs'
path = require 'path'
WebSocket = require 'ws'

# creates a dummy file that we can bump for testing
dummy = (callback) ->
  tmp.file {prefix: 'livereload-', postfix: '.js'}, (err, filepath, fd) ->
    return callback(err) if err

    bump = (callback) ->
      fs.writeFile filepath, Math.random() + '', callback

    # bootstrap the file
    bump () ->
      callback undefined,
        dir: path.dirname(filepath)
        bump: bump

describe 'livereload http file serving', ->

  it 'should parse command line options', (done) ->
    called = false
    command = proxyquire '../lib/command', './livereload':
      createServer: (opts) ->
        called = true
        opts.port.should.equal '3000'
        opts.interval.should.equal '1000'
        opts.fast.should.be.true

        return watch: () ->

    oldLog = console.log
    oldArgs = process.argv
    console.log = () ->
    process.argv = ['node', 'yoinks', '-p', '3000', '-i', '1000', '-f']
    command.run()
    process.argv = oldArgs
    console.log = oldLog

    called.should.be.true
    done()

  it 'should serve up livereload.js', (done) ->
    server = livereload.createServer({port: 35729})

    fileContents = fs.readFileSync('./ext/livereload.js').toString()

    request 'http://localhost:35729/livereload.js?snipver=1', (error, response, body) ->
      should.not.exist error
      response.statusCode.should.equal 200
      fileContents.should.equal body

      server.config.server.close()

      done()

  it 'should connect to the websocket server', (done) ->
    server = livereload.createServer({port: 35729})

    ws = new WebSocket('ws://localhost:35729/livereload')
    ws.on 'message', (data, flags) ->
      data.should.equal '!!ver:1.6'

      server.config.server.close()

      done()

  it 'should allow you to override the internal http server', (done) ->
    app = http.createServer (req, res) ->
      if url.parse(req.url).pathname is '/livereload.js'
        res.writeHead(200, {'Content-Type': 'text/javascript'})
        res.end '// nothing to see here'

    server = livereload.createServer({port: 35729, server: app})

    request 'http://localhost:35729/livereload.js?snipver=1', (error, response, body) ->
      should.not.exist error
      response.statusCode.should.equal 200
      body.should.equal '// nothing to see here'

      server.config.server.close()

      done()

  it 'should allow you to specify ssl certificates to run via https', (done)->
    server = livereload.createServer
      port: 35729
      https:
        cert: fs.readFileSync path.join __dirname, 'ssl/localhost.cert'
        key: fs.readFileSync path.join __dirname, 'ssl/localhost.key'

    fileContents = fs.readFileSync('./ext/livereload.js').toString()

    # allow us to use our self-signed cert for testing
    unsafeRequest = request.defaults
      strictSSL: false
      rejectUnauthorized: false

    unsafeRequest 'https://localhost:35729/livereload.js?snipver=1', (error, response, body) ->
      should.not.exist error
      response.statusCode.should.equal 200
      fileContents.should.equal body

      server.config.server.close()

      done()

  it 'should allow fast watching using fs.watch', (done) ->
    server = livereload.createServer
      port: 35729
      fast: true
    done()

describe 'livereload file watching', ->

  it 'should correctly watch common files', ->
    # TODO check it watches default exts

  it 'should correctly ignore common exclusions', ->
    # TODO check it ignores common exclusions

  it 'should not exclude a dir named git', ->
    # cf. issue #20

  it 'should correctly use fast watching', (done) ->
    server = livereload.createServer
      port: 35728
      fast: true

    # monkey patch debug to listen
    startTime = 0
    server.debug = (str) ->
      # console.log 'Reload took', (Date.now() - startTime)
      done()

    dummy (err, f) ->
      server.watch f.dir
      setTimeout (() ->
          startTime = Date.now()
          f.bump () ->
        ), 500



