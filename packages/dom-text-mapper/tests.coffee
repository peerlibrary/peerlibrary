Tinytest.add 'dom-text-mapper', (test) ->
  isDefined = false
  try
    DTM
    isDefined = true

  test.isTrue isDefined, "DTM is not defined"
  test.isTrue Package['dom-text-mapper'].DTM, "Package.dom-text-mapper.DTM is not defined"

  test.isTrue DTM.DomTextMapper, "DTM.DomTextMapper is not defined"
  test.isTrue DTM.PageTextMapperCore, "DTM.PageTextMapperCore is not defined"
  test.isTrue DTM.DomTextMatcher, "DTM.DomTextMatcher is not defined"
