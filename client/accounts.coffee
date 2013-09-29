Template.displayIcon.userIconUrl = ->
  user = Meteor.user()

  # TODO: We should specify default URL to the image of an avatar which is generated from name initials
  "https://secure.gravatar.com/avatar/#{ user.gravatarHash }?s=25"

Meteor.subscribe 'userData'