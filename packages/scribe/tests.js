Tinytest.add('scribe', function (test) {
  var isDefined = false;
  try {
    Scribe;
    isDefined = true;
  }
  catch (e) {
  }
  test.isTrue(isDefined, "Scribe is not defined");
  test.isTrue(Package.scribe.Scribe, "Package.scribe.Scribe is not defined");
});
