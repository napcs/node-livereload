runner = ->

  livereload = require './livereload'
  resolve    = require('path').resolve
  opts       = require 'opts'

  opts.parse [
    {
      short: "p"
      long:  "port"
      description: "Specify the port"
      value: true
      required: false
    }
    {
      short: "i"
      long:  "interval"
      description: "Specify the interval"
      value: true
      required: false
    }
    {
      short: "f"
      long:  "fast"
      description: "Use faster watching (doesn't work on networked filesystems)"
      value: false
    }
  ].reverse(), true

  port = opts.get('port') || 35729
  interval = opts.get('interval') || 1000
  fast = !!opts.get('fast')

  server = livereload.createServer({port: port, interval: interval, fast: fast, debug: true})

  path = resolve(process.argv[2] || '.')

  console.log "Starting LiveReload for #{path} on port #{port}."

  server.watch(path)

  console.log "Polling for changes every #{interval}ms."

module.exports =
  run: runner
