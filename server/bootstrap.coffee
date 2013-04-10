do -> # To not pollute the namespace
  INITIAL_USERNAME = 'carl-sagan'
  INITIAL_PASSWORD = 'hello'

  Meteor.startup ->
    console.log "Starting PeerLibrary"

    if Meteor.users.find().count() == 0
      console.log "Populating users"

      Accounts.createUser
        email: 'cs@cornell.edu'
        username: INITIAL_USERNAME
        password: INITIAL_PASSWORD
        profile:
          firstName: 'Carl'
          lastName: 'Sagan'
          position: 'Professor of Physics'
          institution: 'Cornell University'

      console.log "Created user with username #{ INITIAL_USERNAME } and password #{ INITIAL_PASSWORD }"

    console.log "Done"
