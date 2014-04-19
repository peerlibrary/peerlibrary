Package.describe({
  summary: "A rich text editor framework for the web platform"
});

Package.on_use(function (api) {
  api.use('define');

  api.export('Scribe');

  api.add_files([
    'scribe/scribe.js',
    'scribe-plugin-blockquote-command/scribe-plugin-blockquote-command.js',
    'scribe-plugin-curly-quotes/scribe-plugin-curly-quotes.js',
    'scribe-plugin-link-prompt-command/scribe-plugin-link-prompt-command.js',
    'scribe-plugin-sanitizer/scribe-plugin-sanitizer.js',
    'client.js'
  ], 'client');
});

Package.on_test(function (api) {
  api.use(['scribe', 'tinytest', 'test-helpers'], 'client');
  api.add_files('tests.js', 'client');
});
