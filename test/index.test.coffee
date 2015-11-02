livereload = require '../lib/livereload'
should = require 'should'
request = require 'request'
http = require 'http'
url = require 'url'
fs = require 'fs'
path = require 'path'
WebSocket = require 'ws'
rmdir = require 'rmdir'

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

  it 'should correctly watch common files', (done) ->
    dir = path.join('test', 'output')
    file = path.join(dir, 'index.')
    server = livereload.createServer({port: 35729})
    exts = ['html', 'css', 'js', 'png', 'gif', 'jpg', 'php', 'php5', 'py', 'rb', 'erb', 'coffee']
    testFiles = []
    responses = []

    i = 0
    while i < exts.length
      testFiles.push file + exts[i]
      responses.push file + exts[i]
      i++

    # create folder to watch, but reset it if exists (from a previous broken test)
    if fs.existsSync(dir)
      rmdir dir, (error) ->
        should.not.exist error
        fs.mkdirSync(dir)
    else
      fs.mkdirSync(dir)

    server.watch(dir);
    ws = new WebSocket('ws://localhost:35729/livereload')

    ws.on 'message', (data, flags) ->
      if data == '!!ver:1.6'
        # this is the when we are connected to the server
        # so we can now modify the files
        i = 0
        while i < testFiles.length
          fs.writeFileSync testFiles[i], 'a'
          i++
      else
        try
          res = JSON.parse(data)
        catch error
          should.not.exist error

        pos = responses.indexOf(res[1].path)
        pos.should.not.equal -1
        res[0].should.equal 'refresh'

        responses.splice(pos, 1)

      if responses.length == 0
        server.config.server.close()
        ws.close()
        rmdir dir, ->
        done()

  it 'should correctly ignore common exclusions', ->
    # TODO check it ignores common exclusions

  it 'should not exclude a dir named git', ->
    # cf. issue #20
