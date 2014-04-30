if Meteor.users.findOne {}
  __meteor_runtime_config__.INSTALL = @INSTALL = false

else if Meteor.settings.autoInstall?.password
  __meteor_runtime_config__.INSTALL = @INSTALL = false

  adminId = Accounts.createUser
    username: 'admin'
    password: Meteor.settings.autoInstall.password

  Person.documents.update
    'user._id': adminId
  ,
    $set:
      isAdmin: true

  if Meteor.settings.autoInstall.sampleData
    Meteor.startup ->
      Meteor.call 'sample-data'

else
  __meteor_runtime_config__.INSTALL = @INSTALL = true