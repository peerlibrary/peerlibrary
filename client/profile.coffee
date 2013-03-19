do -> # To not pollute the namespace
  Template.profile.profiles = ->
    Meteor.users.find
      username: Session.get 'currentProfileUsername'
