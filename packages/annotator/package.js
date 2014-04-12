Package.describe({
  summary: "Annotator plugin"
});

Package.on_use(function (api) {
  api.use(['coffeescript', 'jquery'], 'client');

  api.export('Annotator');

  api.add_files([
    'annotator/src/extensions.coffee',
    'annotator/src/console.coffee',
    'annotator/src/class.coffee',
    'annotator/src/range.coffee',
    'annotator/src/anchors.coffee',
    'annotator/src/highlights.coffee',
    'annotator/src/annotator.coffee',
    'annotator/src/xpath.coffee',
    'annotator/src/plugin/domtextmapper.coffee',
    'annotator/src/plugin/texthighlights.coffee',
    'annotator/src/plugin/textanchors.coffee',
    'annotator/src/plugin/textrange.coffee',
    'annotator/src/plugin/textposition.coffee',
    'annotator/src/plugin/textquote.coffee'
  ], 'client', {bare: true});
});

Package.on_test(function (api) {
  api.use(['annotator', 'tinytest', 'test-helpers', 'coffeescript'], 'client');
  api.add_files('tests.coffee', 'client');
});
