Template.profile.profiles = ->
  Meteor.users.find
    username: Session.get 'currentProfileUsername'
