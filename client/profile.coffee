Deps.autorun ->
  Meteor.subscribe 'users-by-username', Session.get 'currentProfileUsername'
  Meteor.subscribe 'persons-by-username', Session.get 'currentProfileUsername'
  Meteor.subscribe 'publications-by-owner', Session.get 'currentProfileUsername'

Template.profile.person = ->
  Persons.findOne
    user: Session.get 'currentProfileUsername'

Template.profile.publications = ->
  Publications.find
    owner: Session.get 'currentProfileUsername'