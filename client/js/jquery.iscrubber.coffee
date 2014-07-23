###
  jQuery iScrubber plugin 1.0.0

  Created by Marco Martins
  https://github.com/skarface/iscrubber.git
###

$.fn.iscrubber = (customOptions) ->

  $.fn.iscrubber.defaultOptions =
    showItem: 1
    leaveToFirst: true

  # Set the options.
  options = $.extend({}, $.fn.iscrubber.defaultOptions, customOptions)

  # scrub function
  scrub = (elements, itemToShow) ->
    elements.css('display', 'none')
    $(elements[itemToShow-1]).css('display', 'block')

  this.each ->
    $this = $(this)

    return if $this.data('iscrubber-enabled')
    $this.data('iscrubber-enabled', true)

    # get elements
    elements = $this.find('li')

    # set correct width from children and add minimal css require
    width = elements.first().width()
    $this.width(width).css('padding', 0)

    # get trigger width => (scrubber width / number of children)
    numberOfChildren = $this.children().length
    trigger = width / numberOfChildren

    # show first element
    scrub(elements, options.showItem)

    # bind event when mouse moves over scrubber
    $this.on 'mousemove.iscrubber', (e) ->
      # get x mouse position
      x = e.pageX - $this.offset().left

      # get the index of image to display on top
      index = Math.ceil(x/trigger)
      index = Math.min(Math.max(index, 1), numberOfChildren)
      scrub(elements, index)

    # bind event when mouse leaves scrubber
    $this.on 'mouseleave.iscrubber', ->
      scrub(elements, options.showItem) if options.leaveToFirst is true

