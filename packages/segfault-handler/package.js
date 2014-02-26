Package.describe({
  summary: "Capture node.js stack trace on SIGSEGV or SIGBUS"
});

Npm.depends({
  'segfault-handler': "https://github.com/peerlibrary/node-segfault-handler/tarball/a9068c1b25d7713c8a349e826c1b8b8f23e1366a"
});

Package.on_use(function (api) {
  api.export('SegfaultHandler');

  api.add_files([
    'server.js'
  ], 'server');
});
