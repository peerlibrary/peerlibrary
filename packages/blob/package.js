Package.describe({
  summary: "Polyfill for Blob"
});

Package.on_test(function (api) {
  api.add_files([
    'Blob/Blob.js',
  ], 'client', {bare: true});
});
