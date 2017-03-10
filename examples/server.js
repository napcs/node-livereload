var liveReload = require('./lib/livereload');

const ary = [
    'md',
    'text'
];

const liveReloadServer = liveReload.createServer({
	port: 35729,
  debug: true,
        exts: ary
}).watch(__dirname);

