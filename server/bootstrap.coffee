do -> # To not pollute the namespace
  ARXIV_DATA = 'https://github.com/peerlibrary/peerlibrary-data/raw/master/data.json'

  Meteor.startup ->
    console.log "Starting PeerLibrary"

    if Meteor.users.find().count() == 0 and Publications.find().count() == 0
      console.log "Populate database with sample data"

      console.log "Populating users"

      Accounts.createUser
        email: 'cs@cornell.edu'
        username: 'carl-sagan'
        password: 'hello'
        profile:
          firstName: 'Carl'
          lastName: 'Sagan'
          position: 'Professor of Physics'
          institution: 'Cornell University'

      console.log "Populating publications"

      console.log "Downloading arXiv data"

      publications = Meteor.http.get ARXIV_DATA,
        timeout: 10000 # ms

      if publications.error
        throw publications.error
      else if publications.statusCode != 200
        throw new Meteor.Error 500, "Downloading failed"

      publications = JSON.parse(publications.content)

      console.log "Importing arXiv data"

      for publication in publications
        assert.equal publication.source, 'arXiv', "#{ publication.foreignId }: #{ publication.source }"

        # TODO: Map msc2010, acm1998, and foreignCategories to tags
        _.extend publication,
          tags: [publication.source]
          # TODO: Just temporary, remove
          owner: 'carl-sagan'

        Publications.insert publication

    Publications.find({processed: {$ne: true}}).forEach (publication) ->
      if not publication.downloaded
        console.log "Downloading #{ publication._id } from #{ publication.url() }"
        file = publication.download()

      # TODO: Process and store text and paragraphs

    console.log "Done"
