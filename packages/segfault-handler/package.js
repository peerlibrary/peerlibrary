Package.describe({
  summary: "Capture node.js stack trace on SIGSEGV or SIGBUS"
});

Npm.depends({
  'segfault-handler': "https://github.com/peerlibrary/node-segfault-handler/tarball/34026c4a3992f98c24d4d68cfcd429096943a7ad"
});

Package.on_use(function (api) {
  api.export('SegfaultHandler');

  api.add_files([
    'server.js'
  ], 'server');
});
