Package.describe({
  summary: "SHA256 worker package"
});

Package.on_use(function (api) {
  api.use(['coffeescript', 'logging'], ['client', 'server']);

  api.export('SHA256Worker');

  api.add_files([
    'worker.coffee',
    'lib/crypto.coffee'
  ], ['client', 'server']);

  api.add_files([
    'server/crypto.coffee'
  ], 'server' );
  api.add_files([
    'client/crypto.coffee'
  ], 'client' );

	api.add_files([
		'digest.js/digest.js',
		'web-worker.js'
	], 'client', {isAsset: true});
});

Package.on_test(function (api) {
  api.use(['sha256', 'tinytest', 'test-helpers', 'coffeescript'], ['client', 'server']);

  api.add_files(['tests.coffee'], ['client', 'server']);
  api.add_files(['tracemonkey.pdf', 'tracemonkey.txt'], ['client', 'server'], {isAsset: true});
});
