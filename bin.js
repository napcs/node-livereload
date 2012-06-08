#!/usr/bin/env node

var resolve = require('path').resolve
var path = resolve(process.argv[2] || '.')
var livereload = require('./livereload')
var server = livereload.createServer({debug: true})

server.watch(path)
console.log('live reloading ' + path)
