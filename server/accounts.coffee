Meteor.publish 'userData', ->
  Meteor.users.find
    _id: @userId
  ,
    fields:
      gravatarHash: 1
