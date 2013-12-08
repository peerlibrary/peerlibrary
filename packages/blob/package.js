// We are using this package only to polyfill Blob implementation on
// PhantomJS which is used in our Travis CI tests. PhantomJS uses
// internally an old WebKit implementation which has some bugs.
//
// See:
// https://github.com/peerlibrary/peerlibrary/issues/157
// https://github.com/ariya/phantomjs/issues/11013

Package.describe({
  summary: "Polyfill for Blob"
});

Package.on_test(function (api) {
  api.add_files([
    'Blob/Blob.js'
  ], 'client', {bare: true});
});
