Tinytest.add 'dom-text-mapper', (test) ->
  isDefined = false
  try
    DomTextMapper
    isDefined = true

  test.isTrue isDefined, "DomTextMapper is not defined"
  test.isTrue Package['dom-text-mapper'].DomTextMapper, "Package.dom-text-mapper.DomTextMapper is not defined"

  isDefined = false
  try
    PageTextMapperCore
    isDefined = true

  test.isTrue isDefined, "PageTextMapperCore is not defined"
  test.isTrue Package['dom-text-mapper'].PageTextMapperCore, "Package.dom-text-mapper.PageTextMapperCore is not defined"

  isDefined = false
  try
    DomTextMatcher
    isDefined = true

  test.isTrue isDefined, "DomTextMatcher is not defined"
  test.isTrue Package['dom-text-mapper'].DomTextMatcher, "Package.dom-text-mapper.DomTextMatcher is not defined"
