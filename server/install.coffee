Meteor.methods
  'create-admin-account': (password) ->
    check password, String

    throw new Meteor.Error 403, "Not in install mode." unless INSTALL

    throw new Meteor.Error 400, "Password must be at least 6 characters long." unless password and password.length >= 6

    adminId = Accounts.createUser
      username: 'admin'
      password: password

    Person.documents.update
      'user._id': adminId
    ,
      $set:
        isAdmin: true

    # Clients also automatically reload
    Log.info "Restarting PeerLibrary to finish installation"

    Meteor.setTimeout ->
      process.exit 0
    ,
      500

    # Make sure CoffeeScript does not return setTimeout ID because that breaks stack
    return
