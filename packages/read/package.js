Package.describe({
  summary: "Meteor smart package for read node.js package"
});

Npm.depends({
  read: "1.0.5"
});

Package.on_use(function (api) {
  api.export('read');

  api.add_files([
    'server.js'
  ], 'server');
});

Package.on_test(function (api) {
  api.use(['read', 'tinytest', 'test-helpers'], ['server']);
  api.add_files('tests.js', ['server']);
});
