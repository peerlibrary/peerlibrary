if Meteor.users.findOne {}
  __meteor_runtime_config__.INSTALL = @INSTALL = false

else if Meteor.settings.autoInstall?.password
  __meteor_runtime_config__.INSTALL = @INSTALL = false

  Meteor.startup ->
    adminId = Accounts.createUser
      username: 'admin'
      password: Meteor.settings.autoInstall.password

    Person.documents.update
      'user._id': adminId
    ,
      $set:
        isAdmin: true

    Meteor.call 'sample-data' if Meteor.settings.autoInstall.sampleData

else
  __meteor_runtime_config__.INSTALL = @INSTALL = true