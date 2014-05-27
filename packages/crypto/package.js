Package.describe({
  summary: "Crypto package"
});

Package.on_use(function (api) {
  api.export('Crypto');

  api.use(['coffeescript'], ['client', 'server']);
  api.use(['blob'], ['client']);

  api.add_files([
    'lib/crypto.coffee'
  ], ['client', 'server']);

  api.add_files([
    'server/crypto.coffee',
  ], 'server' );
  api.add_files([
    'client/crypto.coffee',
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

  api.add_files(['lib/tests.coffee'], ['client', 'server']);
  api.add_files([
    'client/tests_generic.coffee',
    'client/tests_any_worker.coffee',
    'client/tests_web_worker.coffee',
    'client/tests_fallback_worker.coffee',
    'client/tests_run.coffee'
  ], ['client']);
  api.add_files(['server/tests.coffee'], ['server']);
  api.add_files(['assets/test.pdf'], ['client', 'server'], {isAsset: true});
});
