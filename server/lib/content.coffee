cleanElement = ($, allowedTags, $element) ->
  assert.equal $element.length, 1

  if $element[0].type is 'tag'
    return unless $element[0].name of allowedTags

    allowedAttributes = allowedTags[$element[0].name]

    for attribute, value of $element[0].attribs when not allowedAttributes[attribute]
      $element.removeAttr attribute

    # Special case for links
    if $element[0].name is 'a' and 'href' of $element[0].attribs
      href = $element.attr('href')
      # If local absolute URL
      if href[0] is '/'
        # We prepend root URL so that we can reuse the same normalization code
        rootUrl = Meteor.absoluteUrl()
        rootUrl = rootUrl.substr 0, rootUrl.length - 1 # Remove trailing /
        href = "#{ rootUrl }#{ href }"
      # If link is not valid and not HTTP or HTTPS, normalize
      # returns null and attribute is then removed.
      # TODO: Do we want to allow mailto: links?
      href = UrlUtils.normalize href
      if href and rootUrl
        # Normalization should not change the root URL part
        assert _.startsWith href, rootUrl
        # We remove root URL to return back to local absolute URL
        href = href.substring rootUrl.length
      $element.attr 'href', href

    $cleanedContents = $element.contents().map (i, element) -> cleanElement $, allowedTags, $(element)
    $element.empty().append $cleanedContents
    return $element[0]

  else if $element[0].type is 'text'
    return $element[0]

  else
    return

cleanHTML = (body, allowedTags) ->
  $ = cheerio.load body,
    normalizeWhitespace: true
    decodeEntities: true

  $cleanedContents = $.root().contents().map (i, element) -> cleanElement $, allowedTags, $(element)
  $.root().empty().append($cleanedContents).html()

@cleanInlineHTML = (body) ->
  cleanHTML body, INLINE_ALLOWED_TAGS

@cleanBlockHTML = (body) ->
  cleanHTML body, BLOCK_ALLOWED_TAGS
