livereload = require '../lib/livereload'
should = require 'should'
request = require 'request'
http = require 'http'
url = require 'url'
fs = require 'fs'
path = require 'path'
WebSocket = require 'ws'

describe 'livereload http file serving', ->

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

describe 'livereload file watching', ->

  # it 'should correctly watch common files', (done) ->
  #   # TODO check it watches default exts
  #   server = livereload.createServer({port: 35729})
  #   server.watch('./test/output');
  #   file = 'test/output/index.';
  #   exts = server.config.exts
  #   clone = exts.slice 0
  #   ws = new WebSocket('ws://localhost:35729/livereload')

  #   ws.on 'message', (data, flags) ->
  #     if data == '!!ver:1.6'
  #       i = 0
  #       while i < exts.length
  #         fs.writeFile file + exts[i]
  #         i++
  #     else
  #       res = JSON.parse(data)
  #       ext = res[1].path.match(/(\.)([0-9a-z]+$)/i)[2];
  #       pos = clone.indexOf(ext)
        
  #       pos.should.not.equal -1
  #       res[0].should.equal 'refresh'
        
  #       clone.splice(pos, 1)
  #       fs.unlink file + ext

  #       if clone.length == 0
  #         server.config.server.close()
  #         done()
  it 'should correctly watch common files', (done) ->
    # TODO check it watches default exts
    server = livereload.createServer({port: 35729})
    server.watch('./test/output');
    file = 'test/output/index.';
    exts = server.config.exts
    clone = exts.slice 0
    ws = new WebSocket('ws://localhost:35729/livereload')

    recursive = () ->
      ws.removeListener('message', first)
      one = clone.shift
      console.log one
      ws.on('message', recursive)
      fs.writeFile file + one, '', recursive

    second = (a, b, c, d) ->
      console.log a, b, c, d

    first = (data, flags) ->
      ws.removeListener('message', first)
      one = clone.shift
      ws.on('message', second)
      # i = 0
      # while i < exts.length
      #   fs.writeFile file + exts[i], '', second(i, exts[i])
      #   i++

    ws.on 'message', first
      # else
      #   res = JSON.parse(data)
      #   ext = res[1].path.match(/(\.)([0-9a-z]+$)/i)[2];
      #   pos = clone.indexOf(ext)
        
      #   pos.should.not.equal -1
      #   res[0].should.equal 'refresh'
        
      #   clone.splice(pos, 1)
      #   fs.unlink file + ext

      #   if clone.length == 0
      #     server.config.server.close()
      #     done()

  it 'should correctly ignore common exclusions', ->
    # TODO check it ignores common exclusions

  it 'should not exclude a dir named git', ->
    # cf. issue #20
