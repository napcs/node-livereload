const LiveReload = require('../lib/livereload');

const extensionsToWatch = [
  'md',
  'text'
];

const liveReloadServer = LiveReload.createServer({
  port: 35729,
  debug: true,
  exts: extensionsToWatch
});

liveReloadServer.watch(__dirname);
