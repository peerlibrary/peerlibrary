Package.describe({
  summary: "A rich text editor framework for the web platform"
});

Package.on_use(function (api) {
  api.use('define');

  api.export('Scribe');

  api.add_files([
    'scribe/scribe.js',
    'scribe-plugin-blockquote-command/scribe-plugin-blockquote-command.js',
    'scribe-plugin-heading-command/scribe-plugin-heading-command.js',
    'scribe-plugin-intelligent-unlink-command/scribe-plugin-intelligent-unlink-command.js',
    'scribe-plugin-keyboard-shortcuts/scribe-plugin-keyboard-shortcuts.js',
    'scribe-plugin-link-prompt-command/scribe-plugin-link-prompt-command.js',
    'scribe-plugin-sanitizer/scribe-plugin-sanitizer.js',
    'scribe-plugin-toolbar/scribe-plugin-toolbar.js',
    'client.js'
  ], 'client');
});

Package.on_test(function (api) {
  api.use(['scribe', 'tinytest', 'test-helpers'], 'client');
  api.add_files('tests.js', 'client');
});
