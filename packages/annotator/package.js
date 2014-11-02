Package.describe({
  summary: "Annotator plugin"
});

Package.onUse(function (api) {
  api.use(['coffeescript', 'jquery'], 'client');

  api.export('Annotator');

  api.addFiles([
    'annotator/src/extensions.coffee',
    'annotator/src/console.coffee',
    'annotator/src/class.coffee',
    'annotator/src/range.coffee',
    'annotator/src/anchors.coffee',
    'annotator/src/highlights.coffee',
    'annotator/src/annotator.coffee',
    'annotator/src/xpath.coffee',
    'annotator/src/plugin/domtextmapper.coffee',
    'annotator/src/plugin/textanchors.coffee',
    'annotator/src/plugin/textrange.coffee',
    'annotator/src/plugin/textposition.coffee',
    'annotator/src/plugin/textquote.coffee'
  ], 'client', {bare: true});
});

Package.onTest(function (api) {
  api.use(['annotator', 'tinytest', 'test-helpers', 'coffeescript'], 'client');
  api.addFiles('tests.coffee', 'client');
});
