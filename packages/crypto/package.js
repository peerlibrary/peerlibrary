Package.describe({
  summary: "Efficient crypto operations in web workers"
});

Package.on_use(function (api) {
  api.use(['coffeescript', 'underscore', 'assert'], ['client', 'server']);

  api.export('Crypto');

  api.add_files([
    'lib.coffee'
  ], ['client', 'server']);

  api.add_files([
    'arraybuffer.coffee',
    'client.coffee'
  ], 'client' );

  api.add_files([
    'server.coffee'
  ], 'server' );

  // We have to add digest.js in two ways, to be available
  // in a fallback worker, and in a web worker
  api.add_files([
    'digest.js/digest.js'
  ], 'client', {bare: true});

	api.add_files([
		'digest.js/digest.js',
		'assets/worker.js'
	], 'client', {isAsset: true});
});

Package.on_test(function (api) {
  api.use(['crypto', 'tinytest', 'test-helpers', 'coffeescript', 'underscore', 'async'], ['client', 'server']);

  api.add_files([
    'tests/common.coffee',
    'tests/defined.coffee'
  ], ['client', 'server']);

  api.add_files([
    'tests/client.coffee'
  ], 'client');

  api.add_files([
    'tests/server.coffee'
  ], 'server');

  api.add_files([
    'assets/test.pdf'
  ], ['client', 'server'], {isAsset: true});
});
