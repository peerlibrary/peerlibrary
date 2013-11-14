INITIAL_PASSWORD = 'hello'

Meteor.startup ->
  console.log "Starting PeerLibrary"

  if Meteor.users.find({}, limit: 1).count() == 0
    console.log "Populating users"

    # Carl Sagan
    Accounts.createUser
      email: 'sagan@berkeley.edu'
      username: 'carl-sagan'
      password: INITIAL_PASSWORD
      profile:
        foreNames: 'Carl'
        lastName: 'Sagan'
        work: [
          position: 'Professor of Astronomy'
          institution: 'Cornell University'
          startYear: 1971
          endYear: 1996
        ,
          position: 'Miller Fellow'
          institution: 'University of California, Berkeley'
          startYear: 1960
          endYear: 1962
        ]
        education: [
          degree: 'PhD'
          concentration: 'Astronomy'
          institution: 'University of Chicago'
          startYear: 1956
          endYear: 1960
          completed: true
        ,
          degree: 'BS'
          concentration: 'Physics'
          institution: 'University of Chicago'
          startYear: 1951
          endYear: 1955
          completed: true
        ]
        publications: []

    # Hannah Arendt
    Accounts.createUser
      email: 'arendt@berkeley.edu'
      username: 'hannah-arendt'
      password: INITIAL_PASSWORD
      profile:
        foreNames: 'Hannah'
        lastName: 'Arendt'
        work: [
          position: 'Professor of Philosophy'
          institution: 'New School for Social Research'
          startYear: 1967
          endYear: 1975
        ,
          position: 'Visiting Professor'
          institution: 'University of California, Berkeley'
          startYear: 1955
          endYear: 1956
        ]
        education: [
          degree: 'PhD'
          concentration: 'Philosophy'
          institution: 'University of Heidelberg'
          startYear: 1926
          endYear: 1928
          completed: true
        ]
        publications: []

    # Paul Feyerabend
    Accounts.createUser
      email: 'feyerabend@berkeley.edu'
      username: 'paul-feyerabend'
      password: INITIAL_PASSWORD

    console.log "Created users 'carl-sagan', 'hannah-arendt', 'paul-feyerabend' with password '#{ INITIAL_PASSWORD }'"

    console.log "You probably want to populate the database with some publications, you can do that in the admin interface at /admin"

  console.log "Done"
