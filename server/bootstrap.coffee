do -> # To not pollute the namespace
  Meteor.startup ->
    if Publications.find().count() == 0
      console.log "Population database with sample data"

      Accounts.createUser
        email: 'cs@cornell.edu'
        username: 'carl-sagan'
        password: 'hello'
        profile:
          name_first: 'Carl'
          name_last: 'Sagan'
          position: 'Professor of Physics'
          institution: 'Cornell University'

      publications = [
        _id: 'yJWgdtENibW2Z3s5W'
        title: 'Analytical aspects of Brownian motor effect in randomly flashing ratchets'
        owner: 'carl-sagan'
        authors: [
          name: 'Carl Sagan'
          username: 'carl-sagan'
        ]
        score: 42
        pubDate: 'June 2012'
        field: 'Astrophysics'
        topics: 'High Energy Astrophysical Phenomena'
        bookmarkCount: 133
        commentCount: 42
        abstract: 'The muscle contraction, operation of ATP synthase, maintaining the shape of a cell are believed to be secured by motor proteins, which can be modelled using the Brownian ratchet mechanism.'
        
        originalUrl: 'https://github.com/mozilla/pdf.js/raw/master/web/compressed.tracemonkey-pldi-09.pdf'
        downloaded: false
        processed: false
      ]

      for publication in publications
        Publications.insert publication
