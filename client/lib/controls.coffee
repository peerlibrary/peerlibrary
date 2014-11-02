# To close dropdowns when clicking, focusing, or pressing a key somewhere outside
$(document).on 'click focus keypress dragstart', (event) ->
  $('.dropdown-anchor:visible').each (index, element) ->
    $element = $(element)

    # We don't want to affect the login dropdown in the header.
    # That one is hidden through templates instead of javascript.
    return if $element.closest('.login-link-and-dropdown-list').length

    # Don't close a dropdown if the event happened inside it
    trigger = $element.closest('.dropdown-trigger').get(0)
    return if trigger is event.target or $.contains(trigger, event.target)

    $element.hide().trigger('dropdown-hidden')

  return # Make sure CoffeeScript does not return anything

# Close all dropdowns with escape key
$(document).on 'keyup', (event) ->
  if event.keyCode is 27
    # We only operate on dropdowns in the main section, since we don't want to affect
    # the one in the header. That one is hidden through templates instead of javascript.
    $('section .dropdown-anchor:visible').hide().trigger('dropdown-hidden')

  return # Make sure CoffeeScript does not return anything

Meteor.startup ->
  $(document).tooltip
    position:
      my: 'center bottom'
      at: 'center top-10'
    show: 200
    hide: 200
    items: '.tooltip'
