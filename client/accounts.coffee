Template.displayIcon.userIconUrl = ->
  # TODO: We should specify default URL to the image of an avatar which is generated from name initials
  "https://secure.gravatar.com/avatar/#{ Meteor.person()?.gravatarHash }?s=25"

Template._loginButtonsLoggedInDropdownActions.personSlug = ->
  Meteor.person()?.slug

# To close login buttons dialog box when clicking or focusing somewhere outside
$(document).click (e) ->
  Accounts._loginButtonsSession.closeDropdown()

$(document).focus (e) ->
  Accounts._loginButtonsSession.closeDropdown()

# But if clicked inside, we prevent event propagation so that dialog box is not closed
Template._loginButtons.events
  'click #login-buttons': (e, template) ->
    e.stopPropagation()

  'focus #login-buttons': (e, template) ->
    e.stopPropagation()
