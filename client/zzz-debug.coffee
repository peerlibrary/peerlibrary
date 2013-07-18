# Should be last file loaded

# TODO: Add some switch to enable/disable this, or maybe based on the logged-in (admin) user?

pulseNode = (i, node) ->
  return unless node.style

  $node = $(node)
  prePulseCss = $node.data('prePulseCss') ? node.style.cssText
  prePulseBackgroundColor = $node.data('prePulseBackgroundColor') ? $node.css('backgroundColor')
  $node.data(
    'prePulseCss': prePulseCss
    'prePulseBackgroundColor': prePulseBackgroundColor
  ).css('backgroundColor', 'rgba(255,0,0,0.5)').stop('pulseQueue', true).animate(
    backgroundColor: prePulseBackgroundColor
  ,
    duration: 'slow'
    queue: 'pulseQueue'
    done: (animation, jumpedToEnd) ->
      node.style.cssText = prePulseCss
  ).dequeue 'pulseQueue'

pulse = (template) ->
  $(template.firstNode).nextUntil(template.lastNode).addBack().add(template.lastNode).each pulseNode

_.each Template, (template, name) ->
  oldRendered = template.rendered
  counter = 0

  template.rendered = (args...) ->
    console.debug name, "render count: #{ ++counter }"
    oldRendered.apply @, args if oldRendered
    pulse @
