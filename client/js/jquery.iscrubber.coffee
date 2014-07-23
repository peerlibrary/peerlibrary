###
  jQuery iScrubber plugin 1.0.0

  Created by Marco Martins
  https://github.com/skarface/iscrubber.git
###

$.fn.iscrubber = (customOptions) ->

  DIRECTION =
    HORIZONTAL: 'horizontal'
    VERTICAL: 'vertical'
    # combined works either horizontal or vertical, depending on
    # the direction from where the mouse entered the element
    COMBINED: 'combined'

  $.fn.iscrubber.defaultOptions =
    showItem: 1
    leaveToFirst: true
    direction: DIRECTION.HORIZONTAL

  # Set the options.
  options = $.extend({}, $.fn.iscrubber.defaultOptions, customOptions)

  # Set starting active direction. This gets changed only by the combined option.
  activeDirection = options.direction

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

    # set correct size from children and add minimal css require
    width = elements.first().width()
    height = elements.first().height()
    $this.width(width).height(height).css('padding', 0)

    numberOfChildren = $this.children().length

    # get trigger size => (scrubber size / number of children)
    horizontalTrigger = width / numberOfChildren
    verticalTrigger = height / numberOfChildren

    # show first element
    scrub(elements, options.showItem)

    # bind event when mouse moves over scrubber
    $this.on 'mousemove.iscrubber', (e) ->
      if activeDirection is DIRECTION.COMBINED
        # determine which active direction to choose, depending
        # on the side from which the mouse entered the element
        horizontalDistanceToEdge = Math.min(Math.abs(e.pageX - $this.offset().left), Math.abs(e.pageX - $this.offset().left - width))
        verticalDistanceToEdge = Math.min(Math.abs(e.pageY - $this.offset().top), Math.abs(e.pageY - $this.offset().top - height))

        if (horizontalDistanceToEdge < verticalDistanceToEdge)
          activeDirection = DIRECTION.HORIZONTAL
        else
          activeDirection = DIRECTION.VERTICAL

      # get the index of image to display on top
      switch activeDirection
        when DIRECTION.HORIZONTAL
          index = Math.ceil((e.pageX - $this.offset().left) / horizontalTrigger)
        when activeDirection
          index = Math.ceil((e.pageY - $this.offset().top) / verticalTrigger)

      index = Math.min(Math.max(index, 1), numberOfChildren)
      scrub(elements, index)

    # bind event when mouse leaves scrubber
    $this.on 'mouseleave.iscrubber', ->
      scrub(elements, options.showItem) if options.leaveToFirst is true

      activeDirection = DIRECTION.COMBINED if options.direction is DIRECTION.COMBINED

