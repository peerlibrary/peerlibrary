Package.describe({
  summary: "SHA256 worker package"
});

Package.on_use(function (api) {
  api.use(['coffeescript'], ['client', 'server']);

  api.export('SHA256Worker');

  api.add_files([
    'worker.coffee'
  ], ['client', 'server']);

	api.add_files([
		'digest.js/digest.js',
		'web-worker.js'
	], 'client', {isAsset: true});
});

Package.on_test(function (api) {
});
