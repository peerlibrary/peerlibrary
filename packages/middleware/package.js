Package.describe({
  summary: "Meteor publish middleware support"
});

Package.on_use(function (api) {
  api.use(['coffeescript', 'underscore'], 'server');

  api.export('PublishEndpoint');
  api.export('PublishMiddleware');

  api.add_files([
    'server.coffee'
  ], 'server');
});

Package.on_test(function (api) {
  api.use(['middleware', 'tinytest', 'test-helpers', 'coffeescript', 'insecure', 'random', 'assert', 'underscore'], ['client', 'server']);
  api.add_files('tests.coffee', ['client', 'server']);
});
