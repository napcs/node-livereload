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

  it 'should correctly watch common files', (done) ->
    # TODO check it watches default exts
    dir = './test/output/'
    file = dir + 'index.'
    server = livereload.createServer({port: 35729})
    defaultExts = server.config.exts
    cloneExts = defaultExts.slice 0
    
    # create files to watch
    i = 0
    while i < defaultExts.length
      fs.writeFileSync file + defaultExts[i], ''
      i++

    server.watch(dir);
    ws = new WebSocket('ws://localhost:35729/livereload')

    # change files after 1 second
    # this dealy is due to the fact that the refresh function does not run
    # if the time difference between the changes is less than 1 second
    setTimeout (->
      i = 0
      while i < defaultExts.length
        fs.writeFile file + defaultExts[i], ''
        i++
    ), 1000

    ws.on 'message', (data, flags) ->
      if data == '!!ver:1.6'
        # first call when we start the websocket, do nothing
      else
        res = JSON.parse(data)
        ext = res[1].path.match(/(\.)([0-9a-z]+$)/i)[2];
        pos = cloneExts.indexOf(ext)
        
        pos.should.not.equal -1
        res[0].should.equal 'refresh'
        
        cloneExts.splice(pos, 1)
        fs.unlink file + ext

        if cloneExts.length == 0
          server.config.server.close()
          ws.close()

          done()

  it 'should correctly ignore common exclusions', (done) ->
    # TODO check it ignores common exclusions
    dir = './test/output/'
    file = dir + 'index.'
    server = livereload.createServer({port: 35729})
    defaultExts = server.config.exts
    defaultExclusions = server.config.exclusions
    cloneExts = defaultExts.slice 0
    cloneExclusions = defaultExclusions.slice 0

    console.log defaultExclusions

    server.watch(dir);
    ws = new WebSocket('ws://localhost:35729/livereload')

    server.config.server.close()
    ws.close()

    done()

  it 'should not exclude a dir named git', (done) ->
    # cf. issue #20
    done()
