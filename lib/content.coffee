# For inline editor block elements and no <br/>
@INLINE_ALLOWED_TAGS =
  b: {}
  i: {}
  a:
    href: true
  # Used for saving and restoring selection by rangy. It is using also
  # class and style attributes, but we set those ourselves through CSS.
  # TODO: We should make sure we remove any on the server side
  span:
    id: true

@BLOCK_ALLOWED_TAGS = _.extend {}, INLINE_ALLOWED_TAGS,
  p: {}
  br: {}
  blockquote: {}
  ol: {}
  ul: {}
  li: {}
  h4: {} # TODO: We need a toolbar icon for this
