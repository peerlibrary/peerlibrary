Package.describe({
  summary: "A rich text editor framework for the web platform"
});

Package.onUse(function (api) {
  api.use('mrt:define');

  api.export('Scribe');

  api.addFiles([
    'scribe/scribe.js',
    'scribe-plugin-blockquote-command/scribe-plugin-blockquote-command.js',
    'scribe-plugin-heading-command/scribe-plugin-heading-command.js',
    'scribe-plugin-keyboard-shortcuts/scribe-plugin-keyboard-shortcuts.js',
    'scribe-plugin-sanitizer/scribe-plugin-sanitizer.js',
    'scribe-plugin-toolbar/scribe-plugin-toolbar.js',
    'client.js'
  ], 'client');
});

Package.onTest(function (api) {
  api.use(['scribe', 'tinytest', 'test-helpers'], 'client');
  api.addFiles('tests.js', 'client');
});
