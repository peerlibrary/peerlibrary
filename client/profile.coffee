do -> # To not pollute the namespace
  Meteor.startup ->
    Meteor.autorun ->
      Meteor.subscribe 'user', Session.get 'currentProfileUsername'
      Meteor.subscribe 'publications-by', Session.get 'currentProfileUsername'

  Template.profile.profile = ->
    Meteor.users.findOne
      username: Session.get 'currentProfileUsername'

  Template.profile.profileError = ->
    Session.get 'getProfileError'

  Template.profile.publications = ->
    Publications.find
      author: Session.get 'currentProfileUsername'