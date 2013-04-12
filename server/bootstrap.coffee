do -> # To not pollute the namespace
  INITIAL_PASSWORD = ''

  Meteor.startup ->
    console.log "Starting PeerLibrary"

    if Meteor.users.find({}, limit: 1).count() == 0
      console.log "Populating users"

      Accounts.createUser
        email: 'cs@cornell.edu'
        username: 'carl-sagan'
        password: INITIAL_PASSWORD
        profile:
          firstName: 'Carl'
          lastName: 'Sagan'
          position: 'Professor of Astronomy'
          institution: 'Cornell University'
      Accounts.createUser
        email: 'rf@caltech.edu'
        username: 'richard-feynman'
        password: INITIAL_PASSWORD
        profile:
          firstName: 'Richard'
          lastName: 'Feynman'
          position: 'Professor of Physics'
          institution: 'Caltech'
      Accounts.createUser
        email: 'mf@ens.fr'
        username: 'michel-foucault'
        password: INITIAL_PASSWORD
        profile:
          firstName: 'Michel'
          lastName: 'Foucault'
          position: 'Professor of Philosophy'
          institution: 'Ecole Normale Superieure'
      Accounts.createUser
        email: 'jh@uni-frankfurt.de'
        username: 'jurgen-habermas'
        password: INITIAL_PASSWORD
        profile:
          firstName: 'Jurgen'
          lastName: 'Habermas'
          position: 'Professor of Sociology'
          institution: 'Goethe University Frankfurt am Main'
      Accounts.createUser
        email: 'on@unb.br'
        username: 'oscar-niemeyer'
        password: INITIAL_PASSWORD
        profile:
          firstName: 'Oscar'
          lastName: 'Niemeyer'
          position: 'Professor of Architecture'
          institution: 'University of Brasilia'

      console.log "Created user with username \'#{ INITIAL_USERNAME }\' and password \'#{ INITIAL_PASSWORD }\'"

      console.log "You probably want to populate the database with some publications, you can do that in the admin interface at /admin"

    console.log "Done"
