class CanvasTextHighlight extends Annotator.Highlight
  constructor: (anchor, pageIndex, @normedRange) ->
    super anchor, pageIndex

    @_$selectionLayer = $(@normedRange.commonAncestor).closest('.selection-layer')
    @_$highlightsLayer = @_$selectionLayer.prev('.highlights-layer')
    @_highlightsCanvas = @_$highlightsLayer.prev('.highlights-canvas').get(0)
    @_$highlightsControl = @_$selectionLayer.next('.highlights-control')

    @_offset = @_$highlightsLayer.offsetParent().offset()

    @_area = null
    @_box = null
    @_hover = null
    @_$highlight = null

    # We are displaying hovering effect also when mouse is not really over the highlighting, but we
    # have to know if mouse is over the highlight to know if we should remove or not the hovering effect
    # TODO: Rename hovering effect to something else (engaged? active?) and then hovering and other actions should just engage highlight as neccessary
    # TODO: Sync this naming terminology with annotations (there are same states there)
    @_mouseHovering = false

    @_createHighlight()

  _computeArea: (segments) =>
    @_area = 0

    for segment in segments
      @_area += segment.width * segment.height

    return # Don't return the result of the for loop

  _boundingBox: (segments) =>
    @_box = _.clone segments[0]

    for segment in segments[1..]
      if segment.left < @_box.left
        @_box.width += @_box.left - segment.left
        @_box.left = segment.left
      if segment.top < @_box.top
        @_box.height += @_box.top - segment.top
        @_box.top = segment.top
      if segment.left + segment.width > @_box.left + @_box.width
        @_box.width = segment.left + segment.width - @_box.left
      if segment.top + segment.height > @_box.top + @_box.height
        @_box.height = segment.top + segment.height - @_box.top

  _precomputeHover: (segments) =>
    #merge the row
    #first, creat an array named temp whose entries are of the form [segment, logical], where each segment corresponds to each entry of the input array <segments>. The logicals are initially set to true.
    l = segments.length
    temp = []
    for segment in segments
      temp.push([_.clone(segment),true])
    #each segment is a rectangle, now begin to merge the rectangles in the same row into one rectangle
    i = l-1 #begins at the rectangle located at the end
    while i>=0
      current = temp[i][0]
      currentleft = current.left
      currentright = current.left+current.width
      currenttop = current.top
      currentbottom = current.top+current.height
      j = i-1
      while j>=0 and temp[i][1]
        compare = temp[j][0]
        compareleft = compare.left
        compareright = compare.left+compare.width
        comparetop = compare.top
        comparebottom = compare.top+compare.height
        if ((currentleft-compareright<=15) and (currentleft-compareright>=0)) or ((compareleft <= currentleft) and (currentleft <=compareright) and (compareright <=currentright)) #horizontal conditions to merge, need to try some numbers.  
          if currenttop <= comparetop and comparetop <= currentbottom
            temp[j][0].top = currenttop
            temp[j][0].width = currentright-temp[j][0].left
            if comparebottom <= currentbottom
              temp[j][0].height = currentbottom-temp[j][0].top
            else 
              temp[j][0].height = comparebottom-temp[j][0].top
            temp[i][1] = false
          else if comparetop <= currenttop and currenttop <= comparebottom
            temp[j][0].width = currentright-temp[j][0].left
            if comparebottom <= currentbottom
              temp[j][0].height = currentbottom-temp[j][0].top
            temp[i][1] = false
        j--
      i--
    #finish merging the row
    #define temp2 to be the the merged row of the form (segment,true). Notice that now segment is a complete row (shape is rectangle)
    temp2 = []
    for segment in temp
      temp2.push(segment) if segment[1]

    #This step may be redundant, but it checks if any box is contained in any other box
    i = 0
    while i < temp2.length and temp2[i][1]
      current = temp2[i][0]
      currentleft = current.left
      currentright = current.left+current.width
      currenttop = current.top
      currentbottom = current.top+current.height      
      j = 0
      while j < temp2.length and temp2[i][1] and temp2[j][1]
        if j isnt i
          compare = temp2[j][0]
          compareleft = compare.left
          compareright = compare.left+compare.width
          comparetop = compare.top
          comparebottom = compare.top+compare.height
          if (currentleft+1 >= compareleft) and (currentright<= compareright+1) and (currenttop+1>= comparetop) and (currentbottom <= comparebottom+1)
            temp2[i][1] = false
          if (currentleft <= compareleft+1) and (currentright+1>= compareright) and (currenttop<= comparetop+1) and (currentbottom+1 >= comparebottom)
            temp2[j][1] = false
        j++
      i++

    
    #Now going to merge rows
    temp2.sort (a,b) ->
      return if (((a[0].left+a[0].width)<=b[0].left) or (((a[0].left+a[0].width)>b[0].left) and (a[0].top<=b[0].top))) then -1 else 1 
    
    #temp3 is going to group neighbour rows together as a block
    temp3 = []
    i = 0
    while i < temp2.length 
      temp3.push([_.clone(temp2[i][0]),i]) #(segment, group number)
      i++
    L = temp3.length
    swap = 1 #count the number of swaps
    while swap > 0
      swap = 0
      j = 0 #run over temp3
      while j < L
        k = j
        while k < L
          current = temp3[j][0]
          currentleft = current.left
          currentright = current.left+current.width
          currenttop = current.top
          currentbottom = current.top+current.height        
          compare = temp3[k][0]
          compareleft = compare.left
          compareright = compare.left+compare.width
          comparetop = compare.top
          comparebottom = compare.top+compare.height
          #group two rows if they are close to each other, set group number to be equal, i.e., change the group number for all elements in one group to the group number of the other group.
          if (((comparetop-currenttop >=-1) and (comparetop-currentbottom <=7)) or ((currenttop-comparetop >=-1) and (currentbottom-comparetop <=7))) and ((not (currentleft-compareright>5)) and (not (compareleft-currentright>5)) and (temp3[k][1] isnt temp3[j][1])) #here the number 5 is the number of pixels that the horizontal distance between two rows should not exceeds, if they are to be grouped into the same block.  
            t = _.clone(temp3[k][1])
            temp3[k][1] = temp3[j][1]
            m = 0
            while m < L
              temp3[m][1] = temp3[j][1] if (temp3[m][1] is t)
              m++
            swap++
          k++
        j++

    #define temp4 to be grouped rows, e.g., [[row1,row3,row6],[row2,row4],[row5]]
    temp4 = []
    i = 0
    while i < L #i is group number
      temp5 = []
      j = 0
      while j < L
        if temp3[j][1] is i
          temp5.push(_.clone(temp3[j][0]))
        j++
      temp4.push(_.clone(temp5)) if temp5.length>0
      i++

    #for each group, find the vertices of the convex hull
    @_hover = []
    L = temp4.length
    i = 0
    while i < L #i is the group number, for each i, generate an element for drawing in hover
      hoverelt = []
      upperleft = []
      upperright = []
      lowerleft = []
      lowerright = []
      l = temp4[i].length
      j = 0
      while j < l #j is the number of element in the group
        upperleft.push([temp4[i][j].left,temp4[i][j].top])
        upperright.push([temp4[i][j].left+temp4[i][j].width,temp4[i][j].top])
        lowerleft.push([temp4[i][j].left,temp4[i][j].top+temp4[i][j].height])
        lowerright.push([temp4[i][j].left+temp4[i][j].width,temp4[i][j].top+temp4[i][j].height])
        j++

      #want to get hover = [[hoverelt1],..], number of hoverelt's are the same as the group number; [hoverelt1] = [[h_ur],[h_lr],[h_ll],[h_ul]], where [h_ur] = [[pt1_x,pt1_y],..,[ptn_x,ptn_x]] are the vertices in the upperright part of the convex hull, and similar for others.

      upperright.sort (a,b) ->
        return if (a[1]<b[1] or (a[1] is b[1] and a[0]<b[0])) then -1 else 1
      hoverelt_ur = [] 
      j = 0
      while j < l #compare horizontally
        witness = false #witness is false if j'th elt can fill in
        k = 0
        while k < j and not witness
          witness = true if (upperright[j][0]<= upperright[k][0])
          k++
        k = j+1
        while k < l and not witness
          witness = true if (upperright[j][1] is upperright[k][1])
          k++
        hoverelt_ur.push(upperright[j]) if not witness
        j++
      #now hoverelt_ur is an array of points [pt1_x,pt1_y],...,[ptn_x,ptn_y], the vertices in the upperright part of the selected region, sorted from upperleft to lowerright. Always remember that the lower the point is in the region, the larger the y coordinate is; the righter the point is, the larger the x coordinate is.
      #do smoothing
      pixeldiff = 2 #when two points are 2 pixel close in horizontal or vertical direction, then make adjustments
      counter1 = 0 #start with the upperleft most point
      nchange = 1     #number of adjustments made, initially set > 0
      while nchange > 0 #after some adjustments were made at counter1'th element, need to search again for adjustments starting at counter1'th element
        nchange = 0   
        while nchange is 0 and counter1<hoverelt_ur.length-1
          currentpt = hoverelt_ur[counter1]
          nextpt = hoverelt_ur[counter1+1]
          if (nextpt[0]-currentpt[0]<=pixeldiff or nextpt[1]-currentpt[1]<=pixeldiff) #lines no more than "pixeldiff" pixels wide will be smoothed
            hoverelt_ur[counter1][0] = hoverelt_ur[counter1+1][0] #the upperlefter point has the x-coordinate of the lowerrighter point
            hoverelt_ur = hoverelt_ur.filter (pt) -> pt isnt hoverelt_ur[counter1+1] #delete the lowerrighter point
            nchange++
          else
            counter1++
      hoverelt.push(hoverelt_ur) 

      lowerright.sort (a,b) ->
        return if (a[1]<b[1] or (a[1] is b[1] and a[0]>b[0])) then -1 else 1
      hoverelt_lr = [] 
      j = 0
      while j < l #compare horizontally
        witness = false #witness is false if j'th elt can fill in
        k = 0
        while k < j and not witness
          witness = true if (lowerright[j][1] is lowerright[k][1])
          k++
        k = j+1
        while k < l and not witness
          witness = true if (lowerright[j][0] <= lowerright[k][0])
          k++
        hoverelt_lr.push(lowerright[j]) if not witness
        j++
      #now hoverelt_lr is an array of points [pt1_x,pt1_y],...,[ptn_x,ptn_y], the vertices in the lowerright part of the selected region, sorted from upperright to lowerleft
      counter1 = 0 #start with the lowerleft most point
      nchange = 1     #number of adjustments made, initially set > 0
      while nchange > 0 #after some adjustments were made at counter1'th element, need to search again for adjustments starting at counter1'th element
        nchange = 0   
        while nchange is 0 and counter1<hoverelt_lr.length-1
          currentpt = hoverelt_lr[counter1]
          nextpt = hoverelt_lr[counter1+1]
          if (currentpt[0]-nextpt[0]<=pixeldiff or nextpt[1]-currentpt[1]<=pixeldiff) 
            hoverelt_lr[counter1][1] = hoverelt_lr[counter1+1][1] #the upperrighter point has the y-coordinate of the lowerlefter point
            hoverelt_lr = hoverelt_lr.filter (pt) -> pt isnt hoverelt_lr[counter1+1] #delete the lowerlefter point
            nchange++
          else
            counter1++
      hoverelt.push(hoverelt_lr)

      lowerleft.sort (a,b) ->
        return if (a[1]<b[1] or (a[1] is b[1] and a[0]<b[0])) then -1 else 1
      hoverelt_ll = [] 
      j = 0
      while j < l #compare horizontally
        witness = false #witness is false if j'th elt can fill in
        k = 0
        while k < j and not witness
          witness = true if (lowerleft[j][1] is lowerleft[k][1])
          k++
        k = j+1
        while k < l and not witness
          witness = true if (lowerleft[j][0] >= lowerleft[k][0])
          k++
        hoverelt_ll.push(lowerleft[j]) if not witness
        j++
      #now hoverelt_ll is an array of points [pt1_x,pt1_y],...,[ptn_x,ptn_y], the vertices in the lowerleft part of the selected region, sorted from upperleft to lowerright
      counter1 = 0 #start with the upperleft most point
      nchange = 1     #number of adjustments made, initially set > 0
      while nchange > 0 #after some adjustments were made at counter1'th element, need to search again for adjustments starting at counter1'th element
        nchange = 0   
        while nchange is 0 and counter1<hoverelt_ll.length-1
          currentpt = hoverelt_ll[counter1]
          nextpt = hoverelt_ll[counter1+1]
          if (nextpt[0]-currentpt[0]<=pixeldiff or nextpt[1]-currentpt[1]<=pixeldiff)
            hoverelt_ll[counter1][1] = hoverelt_ll[counter1+1][1] #the upperlefter point has the y-coordinate of the lowerrighter point
            hoverelt_ll = hoverelt_ll.filter (pt) -> pt isnt hoverelt_ll[counter1+1] #delete the upperlefter point
            nchange++
          else
            counter1++
      hoverelt.push(hoverelt_ll) 

      upperleft.sort (a,b) ->
        return if (a[1]<b[1] or (a[1] is b[1] and a[0]>b[0])) then -1 else 1
      hoverelt_ul = [] #it will have points [[ul1],[ul2],...], [ul1] = [left,top]
      #begin fill in hoverelt_ul, need upper left most points
      j = 0
      while j < l #compare horizontally
        witness = false #witness is false if j'th elt can fill in
        k = 0
        while k < j and not witness
          witness = true if (upperleft[j][0]>= upperleft[k][0])
          k++
        k = j+1
        while k < l and not witness
          witness = true if (upperleft[j][1] is upperleft[k][1])
          k++
        hoverelt_ul.push(upperleft[j]) if not witness
        j++
      #now hoverelt_ul is an array of points [pt1_x,pt1_y],...,[ptn_x,ptn_y], the vertices in the upperleft part of the selected region, sorted from upperright to lowerleft
      counter1 = 0 #start with the upperright most point
      nchange = 1     #number of adjustments made, initially set > 0
      while nchange > 0 #after some adjustments were made at counter1'th element, need to search again for adjustments starting at counter1'th element
        nchange = 0   
        while nchange is 0 and counter1<hoverelt_ul.length-1
          currentpt = hoverelt_ul[counter1]
          nextpt = hoverelt_ul[counter1+1]
          if (currentpt[0]-nextpt[0]<=pixeldiff or nextpt[1]-currentpt[1]<=pixeldiff)
            hoverelt_ul[counter1][0] = hoverelt_ul[counter1+1][0] #the upperrighter point has the y-coordinate of the lowerlefter point
            hoverelt_ul = hoverelt_ul.filter (pt) -> pt isnt hoverelt_ul[counter1+1] #delete the upperrighter point
            nchange++
          else
            counter1++
      hoverelt.push(hoverelt_ul)  

      @_hover.push(_.clone(hoverelt)) #hover[[hoverelt1],..],[hoverelt1] = [[h_ur],[h_lr],[h_ll],[h_ul]],[h_ur] = [[pt1_x,pt1_y],..,[ptn_x,ptn_y]]
      i++



    return  # Don't return the result of the for loop

  _drawHover: =>
    context = @_highlightsCanvas.getContext('2d')

    # Style used in variables.styl as well, keep it in sync
    # TODO: Ignoring rounded 2px border radius, implement

    context.save()

    context.lineWidth = 1
    # TODO: Colors do not really look the same if they are same as style in variables.styl, why?
    context.strokeStyle = 'rgba(180,170,0,9)'

    #begin to draw
    L = @_hover.length
    context.beginPath()
    i = 0
    while i< L #there are L different blocks to draw
      hoverelt = _.clone(@_hover[i]) #it contains four elements, each element contains vertices in upperright corner or lowerright corner or lowerleft corner or upperleft cornner.
      upperright = hoverelt[0] 
      #console.log hoverelt
      lowerright = hoverelt[1]
      lowerleft = hoverelt[2]
      upperleft = hoverelt[3]
      #begin to draw vertices in upperright corner. these vertices are ordered from upperleft to lowerright
      context.moveTo(upperright[0][0],upperright[0][1])
      j = 0
      while j < (upperright.length-1)
        context.lineTo(upperright[j][0],upperright[j+1][1])
        context.lineTo(upperright[j+1][0],upperright[j+1][1])
        j++
      #begin to draw vertices in lowerright corner. these vertices are ordered from upperright to lowerleft
      j = 0
      while j < (lowerright.length-1)
        context.lineTo(lowerright[j][0],lowerright[j][1])
        context.lineTo(lowerright[j+1][0],lowerright[j][1])
        j++
      context.lineTo(lowerright[j][0],lowerright[j][1])      
      #begin to draw vertices in lowerleft corner. these vertices are ordered from upperleft to lowerright, so start from the last vertex
      j = (lowerleft.length-1)
      while j >0
        context.lineTo(lowerleft[j][0],lowerleft[j][1])
        context.lineTo(lowerleft[j][0],lowerleft[j-1][1])
        j--
      context.lineTo(lowerleft[j][0],lowerleft[j][1])
      #begin to draw vertices in upperleft corner. these vertices are ordered from upperright to lowerleft, so start from the last vertex.
      j = (upperleft.length-1)
      while j > 0
        context.lineTo(upperleft[j][0],upperleft[j][1])
        context.lineTo(upperleft[j-1][0],upperleft[j][1])
        j--
      context.lineTo(upperleft[j][0],upperleft[j][1])
      context.lineTo(upperright[0][0],upperright[0][1])
      i++
    context.closePath()
    #end drawing


    context.stroke()

    # As shadow is drawn both on inside and outside, we clear inside to give a nice 3D effect
    # context.clearRect @_hover.left, @_hover.top, @_hover.width, @_hover.height

    context.restore()

  _hideHover: =>
    context = @_highlightsCanvas.getContext('2d')
    context.clearRect 0, 0, @_highlightsCanvas.width, @_highlightsCanvas.height

    # We restore hovers for other highlights
    highlight._drawHover() for highlight in @anchor.annotator.getHighlights() when @pageIndex is highlight.pageIndex and highlight._$highlight.hasClass 'hovered'

  _sortHighlights: =>
    @_$highlightsLayer.find('.highlights-layer-highlight').detach().sort(
      (a, b) =>
        # Heuristics, we put smaller highlights later in DOM tree which means they will have higher z-index
        # The motivation here is that we want higher the highlight which leaves more area to the user to select the other highlight by not covering it
        # TODO: Should we improve here? For example, compare size of (A-B) and size of (B-A), where A-B is A with (A intersection B) removed
        $(b).data('highlight')._area - $(a).data('highlight')._area
    ).appendTo(@_$highlightsLayer)

  _showControl: =>
    $control = @_$highlightsControl.find('.meta-menu')

    return if $control.is(':visible')

    $control.css(
      left: @_box.left + @_box.width + 1 # + 1 to not overlap border
      top: @_box.top - 2 # - 1 to align with fake border we style
    ).on(
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler
    )

    # Create a reactive fragment. We fetch a reactive document
    # based on _id (which is immutable) to rerender the fragment
    # as document changes.
    highlightsControl = Meteor.render =>
      highlight = Highlight.documents.findOne @annotation?._id
      Template.highlightsControl highlight if highlight

    # Workaround for https://github.com/peerlibrary/peerlibrary/issues/390
    $control.wrap('<div/>').unwrap()

    $control.find('.meta-content').empty().append(highlightsControl)
    $control.show()

  _hideControl: =>
    $control = @_$highlightsControl.find('.meta-menu')

    return unless $control.is(':visible') and not $control.is('.displayed')

    $control.hide().off(
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler
    )
    @_$highlightsControl.find('.meta-menu .meta-content .delete').off '.highlight'

  _clickHandler: (event) =>
    @anchor.annotator._selectHighlight @annotation._id

    return # Make sure CoffeeScript does not return anything

  # We process mouseover and mouseout manually to trigger custom mouseenter and mouseleave events.
  # The difference is that we do $.contains($highlightAndControl, related) instead of $.contains(target, related).
  # We check if related is a child of highlight or control, and not checking only for one of those.
  # This is necessary so that mouseleave event is not made when user moves mouse from a highlight
  # to a control. jQuery's mouseleave is made because target is not the same as $highlightAndControl.
  _hoverHandler: (event) =>
    $highlightAndControl = @_$highlight.add(@_$highlightsControl)

    target = event.target
    related = event.relatedTarget

    # No relatedTarget if the mouse left/entered the browser window
    if not related or (not $highlightAndControl.is(related) and not $highlightAndControl.has(related).length)
      if event.type is 'mouseover'
        event.type = 'mouseenter-highlight'
        $(target).trigger event
        event.type = 'mouseover'
      else if event.type is 'mouseout'
        event.type = 'mouseleave-highlight'
        $(target).trigger event
        event.type = 'mouseout'

  _mouseenterHandler: (event) =>
    @_mouseHovering = true

    @hover false
    return # Make sure CoffeeScript does not return anything

  _mouseleaveHandler: (event) =>
    @_mouseHovering = false

    if @_$highlight.hasClass 'selected'
      @_hideControl()
    else
      @unhover false

    return # Make sure CoffeeScript does not return anything

  _highlightControlBlur: (event) =>
    # This event triggers when highlight control (its input) is not focused anymore
    return if @_$highlightsControl.find('.meta-menu').is(':hover')
    @_hideControl()
    return # Make sure CoffeeScript does not return anything

  hover: (noControl) =>
    # We have to check if highlight already is marked as hovered because of mouse events forwarding
    # we use, which makes the event be send twice, once when mouse really hovers the highlight, and
    # another time when user moves from a highlight to a control - in fact mouseover handler above
    # gets text layer as related target (instead of underlying highlight) so it makes a second event.
    # This would be complicated to solve, so it is easier to simply have this check here.
    if @_$highlight.hasClass 'hovered'
      # We do not do anything, but we still show control if it was not shown already
      @_showControl() unless noControl
      return

    @_$highlight.addClass 'hovered'
    @_drawHover()
    # When mouseenter handler is called by _annotationMouseenterHandler we do not want to show control
    @_showControl() unless noControl

    # We do not want to create a possible cycle, so trigger only if not called by _annotationMouseenterHandler
    $('.annotations-list .annotation').trigger 'highlightMouseenter', [@annotation._id] unless noControl

  unhover: (noControl) =>
    # Probably not really necessary to check if highlight already marked as hovered but to match check above
    unless @_$highlight.hasClass 'hovered'
      # We do not do anything, but we still hide control if it was not hidden already
      @_hideControl() unless noControl
      return

    @_$highlight.removeClass 'hovered'
    @_hideHover()
    # When mouseleave handler is called by _annotationMouseleaveHandler we do not want to show control
    @_hideControl() unless noControl

    # We do not want to create a possible cycle, so trigger only if not called by _annotationMouseleaveHandler
    $('.annotations-list .annotation').trigger 'highlightMouseleave', [@annotation._id] unless noControl

  _annotationMouseenterHandler: (event, annotationId) =>
    @hover true if annotationId in _.pluck @annotation.referencingAnnotations, '_id'
    return # Make sure CoffeeScript does not return anything

  _annotationMouseleaveHandler: (event, annotationId) =>
    @unhover true if annotationId in _.pluck @annotation.referencingAnnotations, '_id'
    return # Make sure CoffeeScript does not return anything

  _createHighlight: =>
    scrollLeft = $(window).scrollLeft()
    scrollTop = $(window).scrollTop()

    # We cannot simply use Range.getClientRects because it returns different
    # things in different browsers: in Firefox it seems to return almost precise
    # but a bit offset values (maybe just more testing would be needed), but in
    # Chrome it returns both text node and div node rects, so too many rects.
    # To assure cross browser compatibility, we compute positions of text nodes
    # in a range manually.
    segments = for node in @normedRange.textNodes()
      $node = $(node)
      $wrap = $node.wrap('<span/>').parent()
      rect = $wrap.get(0).getBoundingClientRect()
      $node.unwrap()

      left: rect.left + scrollLeft - @_offset.left
      top: rect.top + scrollTop - @_offset.top
      width: rect.width
      height: rect.height

    @_computeArea segments
    @_boundingBox segments
    @_precomputeHover segments
    for segment in segments
      console.log segment
    @_$highlight = $('<div/>').addClass('highlights-layer-highlight').append(
      $('<div/>').addClass('highlights-layer-segment').css(segment) for segment in segments
    ).on
      'click.highlight': @_clickHandler
      'mouseover.highlight mouseout.highlight': @_hoverHandler
      'mouseenter-highlight': @_mouseenterHandler
      'mouseleave-highlight': @_mouseleaveHandler
      'annotationMouseenter': @_annotationMouseenterHandler
      'annotationMouseleave': @_annotationMouseleaveHandler
      'highlightControlBlur': @_highlightControlBlur

    @_$highlight.data 'highlight', @

    @_$highlightsLayer.append @_$highlight

    @_sortHighlights()

    # Annotator's anchors are realized (Annotator's highlight is created) when page is rendered
    # and virtualized (Annotator's highlight is destroyed) when page is removed. This mostly happens
    # as user scrolls around. But we want that if our highlight (Annotator's annotation) is selected
    # (selectedAnnotationId is set) when it is realized, it is drawn as selected and also that it is
    # really selected in the browser as a selection. So we do this here.
    @select() if @anchor.annotator.selectedAnnotationId is @annotation._id

  # React to changes in the underlying annotation
  annotationUpdated: =>
    # TODO: What to do when it is updated? Can we plug in reactivity somehow? To update template automatically?
    #console.log "In HL", @, "annotation has been updated."

  # Remove all traces of this highlight from the document
  removeFromDocument: =>
    # When removing, first we have to deselect it and just then remove it, otherwise
    # if this particular highlight is created again browser reselection does not
    # work (tested in Chrome). It seems if you have a selection and remove DOM
    # of text which is selected and then put DOM back and try to select it again,
    # nothing happens, no new browser selection is made. So what was happening
    # was that if you had a highlight selected on the first page (including
    # browser selection of the text in the highlight) and you scroll away so that
    # page was removed and then scroll back for page to be rendered again and
    # highlight realized (created) again, _createHighlight correctly called select
    # on the highlight, all CSS classes were correctly applied (making highlight
    # transparent), but browser selection was not made on text. If we deselect
    # when removing, then reselecting works correctly.
    @deselect() if @anchor.annotator.selectedAnnotationId is @annotation._id

    # We fake mouse leaving if highlight was hovered by any chance
    # (this happens when you remove a highlight through a control).
    @_mouseleaveHandler null

    $(@_$highlight).remove()

  # Just a helper function to draw highlight selected and make it selected by the browser, use annotator._selectHighlight to select
  select: =>
    selection = rangy.getSelection()
    selection.addRange @normedRange.toRange()

    @_$selectionLayer.addClass 'highlight-selected'
    @_$highlight.addClass 'selected'

    # We also want that selected annotations display a hover effect
    @hover true

  # Just a helper function to draw highlight unselected and make it unselected by the browser, use annotator._selectHighlight to deselect
  deselect: =>
    # Mark this highlight as deselected
    @_$highlight.removeClass 'selected'

    # First store any selection which is outside pages
    otherRanges = []
    selection = rangy.getSelection()
    for r in [0...selection.rangeCount]
      range = selection.getRangeAt r
      otherRanges.push range unless $(range.commonAncestorContainer).closest('.display-page').length

    # Deselect everything
    selection.removeAllRanges()

    # We will re-add it in highlight.select() if necessary
    $('.text-layer', @anchor.annotator.wrapper).removeClass 'highlight-selected'

    # And re-select highlights marked as selected
    highlight.select() for highlight in @anchor.annotator.getHighlights() when highlight.isSelected()

    # Reselect selections outside pages
    selection.addRange range for range in otherRanges

    # If mouse is not over the highlight we unhover
    @unhover true unless @_mouseHovering

  # Is highlight currently drawn as selected, use annotator.selectedAnnotationId to get ID of a selected annotation
  isSelected: =>
    @_$highlight.hasClass 'selected'

  in: (clientX, clientY) =>
    @_$highlight.find('.highlights-layer-segment').is (i) ->
      # @ (this) is here a segment, DOM element
      rect = @getBoundingClientRect()

      rect.left <= clientX <= rect.right and rect.top <= clientY <= rect.bottom

  # Get the HTML elements making up the highlight
  _getDOMElements: =>
    @_$highlight

  # Get bounding box with coordinates relative to the outer bounds of the display wrapper
  getBoundingBox: =>
    wrapperOffset = @anchor.annotator.wrapper.outerOffset()

    left: @_box.left + @_offset.left - wrapperOffset.left
    top: @_box.top + @_offset.top - wrapperOffset.top
    width: @_box.width
    height: @_box.height

class Annotator.Plugin.CanvasTextHighlights extends Annotator.Plugin
  pluginInit: =>
    # Register this highlighting implementation
    @annotator.highlighters.unshift
      name: 'Canvas text highlighter'
      highlight: @_createTextHighlight
      isInstance: @_isInstance
      getIndependentParent: @_getIndependentParent

  _createTextHighlight: (anchor, pageIndex) =>
    switch anchor.type
      when 'text range'
        new CanvasTextHighlight anchor, pageIndex, anchor.range
      when 'text position'
        # TODO: We could try to still create a range from trying to anchor with a DOM anchor again, and if it fails, go back to DTM

        # Cannot do this without DTM
        return unless @annotator.domMapper

        # First we create the range from the stored stard and end offsets
        mappings = @annotator.domMapper.getMappingsForCharRange anchor.start, anchor.end, [pageIndex]

        # Get the wanted range out of the response of DTM
        realRange = mappings.sections[pageIndex].realRange

        # Get a BrowserRange
        browserRange = new Annotator.Range.BrowserRange realRange

        # Get a NormalizedRange
        normedRange = browserRange.normalize @annotator.wrapper[0]

        # Create the highligh
        new CanvasTextHighlight anchor, pageIndex, normedRange
      else
        # Unsupported anchor type
        null

  # Is this element a text highlight physical anchor?
  _isInstance: (element) =>
    # Is always false because canvas highlights are completely independent from the content
    false

  # Find the first parent outside this physical anchor
  _getIndependentParent: (element) =>
    # Should never happen because canvas highlights are completely independent from the content
    assert false
