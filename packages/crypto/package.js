Package.describe({
  summary: "Crypto package"
});

Package.on_use(function (api) {
  api.export('Crypto');

  api.use(['coffeescript', 'logging'], ['client', 'server']);
  api.use(['blob'], ['client']);

  api.add_files([
    'lib.coffee'
  ], ['client', 'server']);

  api.add_files([
    'server.coffee',
  ], 'server' );
  api.add_files([
    'client.coffee',
  ], 'client' );

  api.add_files([
    'digest.js/digest.js'
    ], 'client', {bare: true});

	api.add_files([
		'digest.js/digest.js',
		'assets/web-worker.js'
	], 'client', {isAsset: true});

});

Package.on_test(function (api) {
  api.use(['crypto', 'tinytest', 'test-helpers', 'coffeescript'], ['client', 'server']);
  api.use(['jquery'], ['client']);

  api.add_files(['tests/common.coffee'], ['client', 'server']);
  api.add_files([
    'tests/general.coffee',
    'tests/any_worker.coffee',
    'tests/fallback_worker.coffee'
  ], ['client']);
  api.add_files(['tests/server.coffee'], ['server']);
  api.add_files(['assets/test.pdf'], ['client', 'server'], {isAsset: true});
});
