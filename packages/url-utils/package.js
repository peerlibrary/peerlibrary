Package.describe({
  summary: "URL normalization utils"
});

Npm.depends({
  'node-url-utils': "https://github.com/peerlibrary/node-url-utils/tarball/4dd169482ed1f41ddf96e2797fd3fe5dfced57ce"
});

Package.on_use(function (api) {
  api.export('UrlUtils');

  api.add_files([
    'server.js'
  ], 'server');
});
