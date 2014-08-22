Meteor.startup ->
  # We use z-index -1 to hide the loading message once content
  # is loaded, but we still remove it here
  $('.peerlibrary-loading').remove()
