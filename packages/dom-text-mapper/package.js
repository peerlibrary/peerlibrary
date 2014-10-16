Package.describe({
  summary: "dom-text-mapper and dom-text-matcher libraries"
});

Package.onUse(function (api) {
  api.use(['coffeescript'], ['client', 'server']);

  api.export([
    'DomTextMapper',
    'PageTextMapperCore',
    'DomTextMatcher'
  ]);

  api.addFiles([
    'dom-text-matcher/lib/diff_match_patch/diff_match_patch_uncompressed.js',
    'dom-text-matcher/src/text_match_engines.coffee',
    'dom-text-mapper/src/dom_text_mapper.coffee',
    'dom-text-matcher/src/dom_text_matcher.coffee',
    'dom-text-mapper/src/page_text_mapper_core.coffee',
    'dtm.coffee'
  ], ['client', 'server']);
});

Package.onTest(function (api) {
  api.use(['dom-text-mapper', 'tinytest', 'test-helpers', 'coffeescript'], ['client', 'server']);
  api.addFiles('tests.coffee', ['client', 'server']);
});
