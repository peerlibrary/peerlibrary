Meteor.methods
  createAdminAccount: (password) ->
    check password, String

    throw new Meteor.Error "Not in install mode", 403 unless INSTALL

    throw new Meteor.Error "Password is required", 400 unless password

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
