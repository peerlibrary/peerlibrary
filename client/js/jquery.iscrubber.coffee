###
  jQuery iScrubber plugin 1.0.0

  Created by Marco Martins
  https://github.com/skarface/iscrubber.git
###

$.fn.iscrubber = (customOptions) ->

  $.fn.iscrubber.defaultOptions =
    showItem: 0
    leaveToFirst: true

  # Set the options.
  options = $.extend({}, $.fn.iscrubber.defaultOptions, customOptions)

  # scrub function
  scrub = (elements, itemToShow) ->
    elements.css('display', 'none')
    elements.eq(itemToShow).css('display', 'block')

  this.each ->
    $this = $(this)

    return if $this.data('iscrubber-enabled')
    $this.data('iscrubber-enabled', true)

    # get elements
    elements = $this.find('li')

    # set correct width from children and add minimal css require
    width = elements.first().width()
    $this.width(width).css('padding', 0)

    # get trigger width for each page => (scrubber width / number of children)
    count = $this.children().length
    pageTriggerWidth = $this.outerWidth() / count

    # show first element
    scrub(elements, options.showItem)

    # bind event when mouse moves over scrubber
    $this.on 'mousemove.iscrubber', (e) ->
      # get x mouse position and take 1px border into account
      x = e.pageX - $this.offset().left + 1

      # get the index of image to display on top
      index = Math.floor(x/pageTriggerWidth)

      # make sure the index is within bounds (0 <= index < count)
      index = Math.min(Math.max(0, index), count-1)

      scrub(elements, index)

    # bind event when mouse leaves scrubber
    $this.on 'mouseleave.iscrubber', ->
      scrub(elements, options.showItem) if options.leaveToFirst is true

