GetProfile = new Meteor.Collection 'get-profile'

do -> # To not pollute the namespace
  Meteor.startup ->
    Meteor.autorun ->
      Session.set 'getProfileError', undefined
      Meteor.subscribe 'get-profile', Session.get('currentProfileUsername'), {
        onError: (error) ->
          # TODO: Currently, error.reason is always empty, a Meteor bug?
          Session.set 'getProfileError', error.reason ? "Unknown error"
      }

  Template.profile.profile = ->
    Meteor.users.findOne
      username: Session.get 'currentProfileUsername'

  Template.profile.profileError = ->
    Session.get 'getProfileError'
