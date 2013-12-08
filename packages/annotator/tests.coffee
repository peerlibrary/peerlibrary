Tinytest.add 'annotator', (test) ->
  isDefined = false
  try
    Annotator
    isDefined = true

  test.isTrue isDefined, "Annotator is not defined"
  test.isTrue Package['annotator'].Annotator, "Package.annotator.Annotator is not defined"
