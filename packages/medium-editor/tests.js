Tinytest.add('medium-editor', function (test) {
  var isDefined = false;
  try {
    MediumEditor;
    isDefined = true;
  }
  catch (e) {
  }
  test.isTrue(isDefined, "MediumEditor is not defined");
  test.isTrue(Package['medium-editor'].MediumEditor, "Package.medium-editor.MediumEditor is not defined");
});
