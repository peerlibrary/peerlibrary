Meteor.methods
  'create-admin-account': (password) ->
    check password, String

    throw new Meteor.Error 403, "Not in install mode." unless INSTALL

    throw new Meteor.Error 400, "Password is required." unless password

    adminId = Accounts.createUser
      username: 'admin'
      password: password

    Persons.update
      'user._id': adminId
    ,
      $set:
        isAdmin: true

    Log.info "Restarting PeerLibrary to finish installation"

    process.exit 0
