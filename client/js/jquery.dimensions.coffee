(($) ->

  contentsRect = ($element) ->
    $wrap = $element.wrapInner('<span/>').children()
    rect = $wrap.get(0).getBoundingClientRect()
    $wrap.contents().appendTo($wrap.parent())
    $wrap.remove()
    rect

  # Get the current computed width for the contents of the first element in the set of matched elements.
  $.fn.contentsWidth = ->
    rect = contentsRect(this.eq(0))
    rect.width

  # Get the current computed height for the contents of the first element in the set of matched elements.
  $.fn.contentsHeight = ->
    rect = contentsRect(this.eq(0))
    rect.height

  # jQuery offset() returns coordinates of the content part of the element,
  # ignoring any margins. outerOffset() returns outside coordinates of the
  # element, including margins.
  $.fn.outerOffset = ->
    marginLeft = parseFloat(this.css('margin-left'))
    marginTop = parseFloat(this.css('margin-top'))
    offset = this.offset()
    offset.left -= marginLeft
    offset.top -= marginTop
    offset

)(jQuery)
