Tinytest.add('meteor-read', function (test) {
  var isDefined = false;
  try {
    read;
    isDefined = true;
  }
  catch (e) {
  }
  test.isTrue(isDefined, "read is not defined");
  test.isTrue(Package.read.read, "Package.read.read is not defined");
});
