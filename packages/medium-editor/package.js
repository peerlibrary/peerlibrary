Package.describe({
  summary: "Medium.com WYSIWYG editor clone"
});

Package.on_use(function (api) {
  api.export('MediumEditor');

  api.add_files([
    'client-before.js',
    'medium-editor/src/js/medium-editor.js',
    'client-after.js',
    // We are using compiled CSS file because there is no
    // Compass support for node to be able to do it dynamically
    'medium-editor/dist/css/medium-editor.css'
  ], 'client');
});

Package.on_test(function (api) {
  api.use(['medium-editor', 'tinytest', 'test-helpers'], 'client');
  api.add_files('tests.js', 'client');
});
