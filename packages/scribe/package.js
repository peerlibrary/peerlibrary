Package.describe({
  summary: "A rich text editor framework for the web platform"
});

Package.on_use(function (api) {
  api.use('define');

  api.export('Scribe');

  api.add_files([
    'scribe/scribe.js',
	'client.js'
  ], 'client');
});

Package.on_test(function (api) {
  api.use(['scribe', 'tinytest', 'test-helpers'], 'client');
  api.add_files('tests.js', 'client');
});
