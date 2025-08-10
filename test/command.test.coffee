command = require '../lib/command'
should = require 'should'

describe 'CLI argument parsing', ->

  it 'should create server with configuration options', ->
    result = command.createServerFromArgs(['--port', '45001'])
    result.server.config.port.should.equal(45001)
    result.server.config.host.should.equal('localhost')
    result.server.config.debug.should.equal(false)
    result.server.config.usePolling.should.equal(false)
    result.server.config.delay.should.equal(0)
    result.server.config.originalPath.should.equal('')
    result.server.config.cors.should.equal(false)
    result.server.config.corp.should.equal(false)
    result.path.should.be.an.Array()

  it 'should parse port option correctly', ->
    result = command.createServerFromArgs(['--port', '8080'])
    result.server.config.port.should.equal(8080)

  it 'should parse short port option correctly', ->
    result = command.createServerFromArgs(['-p', '45003'])
    result.server.config.port.should.equal(45003)

  it 'should parse host option correctly', ->
    result = command.createServerFromArgs(['--bind', '0.0.0.0'])
    result.server.config.host.should.equal('0.0.0.0')

  it 'should parse short host option correctly', ->
    result = command.createServerFromArgs(['-b', '127.0.0.1'])
    result.server.config.host.should.equal('127.0.0.1')

  it 'should parse debug flag correctly', ->
    result = command.createServerFromArgs(['--debug'])
    result.server.config.debug.should.equal(true)

  it 'should parse short debug flag correctly', ->
    result = command.createServerFromArgs([ '-d'])
    result.server.config.debug.should.equal(true)

  it 'should parse exts option correctly', ->
    result = command.createServerFromArgs(['--exts', 'html,css,js'])
    result.server.config.exts.should.eql(['html', 'css', 'js'])

  it 'should parse short exts option correctly', ->
    result = command.createServerFromArgs(['-e', 'md,txt'])
    result.server.config.exts.should.eql(['md', 'txt'])

  it 'should parse extraExts option correctly', ->
    result = command.createServerFromArgs(['--extraExts', 'scss,less'])
    expectedExts = ['scss', 'less', 'html', 'css', 'js', 'png', 'gif', 'jpg', 'php', 'php5', 'py', 'rb', 'erb', 'coffee']
    result.server.config.exts.should.eql(expectedExts)

  it 'should parse short extraExts option correctly', ->
    result = command.createServerFromArgs(['-ee', 'vue'])
    expectedExts = ['vue', 'html', 'css', 'js', 'png', 'gif', 'jpg', 'php', 'php5', 'py', 'rb', 'erb', 'coffee']
    result.server.config.exts.should.eql(expectedExts)

  it 'should parse filesToReload option correctly', ->
    result = command.createServerFromArgs(['--filesToReload', 'index.html,app.js'])
    result.server.config.filesToReload.should.eql(['index.html', 'app.js'])

  it 'should parse short filesToReload option correctly', ->
    result = command.createServerFromArgs(['-f', 'config.json'])
    result.server.config.filesToReload.should.eql(['config.json'])

  it 'should parse usepolling flag correctly', ->
    result = command.createServerFromArgs(['--usepolling'])
    result.server.config.usePolling.should.equal(true)

  it 'should parse short usepolling flag correctly', ->
    result = command.createServerFromArgs(['-u'])
    result.server.config.usePolling.should.equal(true)

  it 'should parse wait option correctly', ->
    result = command.createServerFromArgs(['--wait', '1000'])
    result.server.config.delay.should.equal(1000)

  it 'should parse short wait option correctly', ->
    result = command.createServerFromArgs(['-w', '500'])
    result.server.config.delay.should.equal(500)

  it 'should parse originalpath option correctly', ->
    result = command.createServerFromArgs(['--originalpath', 'http://example.com'])
    result.server.config.originalPath.should.equal('http://example.com')

  it 'should parse short originalpath option correctly', ->
    result = command.createServerFromArgs(['-op', 'http://localhost:3000'])
    result.server.config.originalPath.should.equal('http://localhost:3000')

  it 'should parse corp flag correctly', ->
    result = command.createServerFromArgs(['--corp'])
    result.server.config.corp.should.equal(true)

  it 'should parse short corp flag correctly', ->
    result = command.createServerFromArgs(['-cp'])
    result.server.config.corp.should.equal(true)

  it 'should parse cors option correctly', ->
    result = command.createServerFromArgs(['--cors', 'http://localhost:8080'])
    result.server.config.cors.should.equal('http://localhost:8080')

  it 'should parse short cors option correctly', ->
    result = command.createServerFromArgs(['-cs', '*'])
    result.server.config.cors.should.equal('*')


  it 'should parse exclusions option correctly', ->
    result = command.createServerFromArgs(['--port', '45025', '--exclusions', '\\.tmp,\\.log'])
    result.server.config.exclusions.should.have.length(5)  # 2 user + 3 defaults
    result.server.config.exclusions[0].should.be.an.instanceOf(RegExp)
    result.server.config.exclusions[1].should.be.an.instanceOf(RegExp)

  it 'should parse short exclusions option correctly', ->
    result = command.createServerFromArgs(['--port', '45026', '-x', 'node_modules'])
    result.server.config.exclusions.should.have.length(4)  # 1 user + 3 defaults
    result.server.config.exclusions[0].should.be.an.instanceOf(RegExp)

  it 'should handle multiple options correctly', ->
    result = command.createServerFromArgs(['-p', '8080', '-d', '--cors', '*', '--exts', 'html,js'])
    result.server.config.port.should.equal(8080)
    result.server.config.debug.should.equal(true)
    result.server.config.cors.should.equal('*')
    result.server.config.exts.should.eql(['html', 'js'])

  it 'should handle path argument correctly', ->
    result = command.createServerFromArgs(['./src'])
    result.path.should.be.an.Array()
    result.path[0].should.match(/\/src$/)

  it 'should handle multiple comma-separated paths correctly', ->
    result = command.createServerFromArgs(['./src,./public'])
    result.path.should.have.length(2)
    result.path[0].should.match(/\/src$/)
    result.path[1].should.match(/\/public$/)

  it 'should use default port when no port specified', ->
    result = command.createServerFromArgs([])
    result.server.config.port.should.equal(35729)
