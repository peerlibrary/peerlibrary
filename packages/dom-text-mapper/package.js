Package.describe({
  summary: "dom-text-mapper and dom-text-matcher libraries"
});

Package.on_use(function (api) {
  api.use(['coffeescript'], ['client', 'server']);

  api.export('DTM');

  api.add_files([
    'dom-text-matcher/lib/diff_match_patch/diff_match_patch_uncompressed.js',
    'dom-text-matcher/src/text_match_engines.coffee',
    'dom-text-mapper/src/dom_text_mapper.coffee',
    'dom-text-matcher/src/dom_text_matcher.coffee',
    'dom-text-mapper/src/page_text_mapper_core.coffee',
    'dtm.coffee'
  ], ['client', 'server']);
});

Package.on_test(function (api) {
  api.use(['dom-text-mapper', 'tinytest', 'test-helpers', 'coffeescript'], ['client', 'server']);
  api.add_files('tests.coffee', ['client', 'server']);
});
