Deps.autorun ->
  Meteor.subscribe 'users', Session.get 'currentProfileUsername'
  Meteor.subscribe 'publications-by-owner', Session.get 'currentProfileUsername'

Template.profile.profile = ->
  Meteor.users.findOne
    username: Session.get 'currentProfileUsername'

Template.profile.publications = ->
  Publications.find
    owner: Session.get 'currentProfileUsername'