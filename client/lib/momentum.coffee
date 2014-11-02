Momentum.registerPlugin 'animatedVerticalList', (options) ->
  options = _.extend {}, options,
    duration: 500
    easing: [250, 15] # Spring physics
    effectDuration: 600 # A bit longer than translation duration
    withSpringEffect: false
    withFadeInEffect: false

  insertElement: (node, next) ->
    $node = $(node)
    $node.insertBefore(next).css(
      # We want for node to go over the other elements.
      position: 'relative'
      zIndex: 1
    )
    if options.withSpringEffect
      # Inserting a new element with the spring effect.
      $node.velocity(
        translateZ: 0
        scale: [1, 0]
      ,
        easing: options.easing
        duration: options.effectDuration
        queue: false
      )
    if options.withFadeInEffect
      # Inserting a new element with the fade in effect.
      $node.velocity(
        'fadeIn'
      ,
        duration: options.effectDuration
        queue: false
      )

    $nextElements = $(next).nextAll().addBack().filter (i, element) ->
      element.nodeType isnt Node.TEXT_NODE
    $nextElements.velocity(
      translateZ: 0
      # We translate next nodes temporary back to the old position.
      translateY: [-1 * $node.outerHeight true]
    ,
      duration: 0
      queue: false
    ).velocity(
      # And then animate them slowly to new position.
      translateY: [0]
    ,
      duration: options.duration
      queue: false
      complete: ->
        $node.css(
          # After it finishes, we remove display and z-index.
          position: ''
          zIndex: ''
        )
    )

    unless $nextElements.length
      # A special case when $nextElements is empty. We have to cleanup.
      $node.css(
        # After it finishes, we remove display and z-index.
        position: ''
        zIndex: ''
      )

  moveElement: (node, next) ->
    $node = $(node)
    # Traversing until a node works better because sometimes next is a text node and
    # then it is not found correctly and nextUntil/prevUntil selects everything.
    # This means that we are traversing backwards so code is a bit less clear.
    # Originally it was $node.prevUntil(next).add(next) and $node.nextUntil(next).
    $prev = $(next).nextUntil(node).add(next) # node is inserted before next, so we add next as well
    $next = $(next).prevUntil(node)

    nodeOuterHeight = $node.outerHeight true

    oldNodeOffset = $node.outerOffset()
    $node.detach().insertBefore(next)
    newNodeOffset = $node.outerOffset()

    $node.css(
      # We want for node to go over the other elements.
      position: 'relative'
      zIndex: 1
    ).velocity(
      translateZ: 0
      # We translate the node temporary back to the old position.
      translateY: [oldNodeOffset.top - newNodeOffset.top]
    ,
      duration: 0
      queue: false
    ).velocity(
      # And then animate them slowly to new position.
      translateY: [0]
    ,
      duration: options.duration
      queue: false
      complete: ->
        $node.css(
          # After it finishes, we remove display and z-index.
          position: ''
          zIndex: ''
        )
    )

    # TODO: Find a better way to determine which elements are between node and next, a way which does not assume order of elements in DOM tree has same direction as elements' positions
    # Currently, we store both previous and next elements and then after the move we determine
    # which are those elements we also have to move to make visually space for a moved node.
    if oldNodeOffset.top - newNodeOffset.top < 0
      # Moving node down
      $betweenElements = $next
    else
      # Moving node up
      $betweenElements = $prev

    $betweenElements = $betweenElements.filter (i, element) ->
      element.nodeType isnt Node.TEXT_NODE

    $betweenElements.velocity(
      translateZ: 0
      # We translate nodes in-between temporary back to the old position.
      translateY: [if oldNodeOffset.top - newNodeOffset.top < 0 then nodeOuterHeight else -1 * nodeOuterHeight]
    ,
      duration: 0
      queue: false
    ).velocity(
      # And then animate them slowly to new position.
      translateY: [0]
    ,
      duration: options.duration
      queue: false
    )

  removeElement: (node) ->
    $node = $(node).css(
      # First, we want to hide the element. It might be already hidden
      # from the fade out, but it does not matter.
      visibility: 'hidden'
    ).velocity(
      # And then slide it up.
      'slideUp'
    ,
      duration: options.duration
      queue: false
      completed: ->
        # At the end we remove the element itself.
        $node.remove()
    )
