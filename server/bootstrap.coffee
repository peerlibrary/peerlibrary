do -> # To not pollute the namespace
  ARXIV_DATA = 'http://dl.dropbox.com/s/ktlkhbn75y4fh05/data.json'

  require = __meteor_bootstrap__.require

  fibers = require 'fibers'
  future = require 'fibers/future'
  http = require 'http'

  httpGetByLine = (url, lineCallback) ->
    httpGetByLineAsync = (finalCallback) ->
      finished = false
      lineCallbackCounter = 0
      lineCallbackWrapped = (line) ->
        lineCallbackCounter++
        lineCallback line
        lineCallbackCounter--
        if finished and lineCallbackCounter == 0
          finalCallback()

      req = http.get(url).on(
        'error', (err) -> throw new Error err
      ).on(
        'response', (response) ->
          console.log "Data size: #{ response.headers['content-length'] / 1024 / 1024 } MB"
          buffer = ''
          response.setEncoding 'utf-8'
          response.on(
            'data', (chunk) ->
              buffer += chunk
              lines = buffer.split '\n'
              for line in lines[0...lines.length-1]
                fibers(lineCallbackWrapped).run(line)
              buffer = lines[lines.length-1]
          ).on(
            'end', () ->
              fibers(lineCallbackWrapped).run(buffer) if buffer
              finished = true
              if lineCallbackCounter == 0
                finalCallback()
          ).on(
            'close', () -> throw new Error "Connection closed"
          )
      )
      req.setTimeout 10000, -> # ms
        req.abort()
    future.wrap(httpGetByLineAsync)().wait()

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

      console.log "Importing arXiv data"

      counter = 0
      httpGetByLine ARXIV_DATA, (line) ->
        publication = JSON.parse(line)

        assert.equal publication.source, 'arXiv', "#{ publication.foreignId }: #{ publication.source }"

        # TODO: Map msc2010, acm1998, and foreignCategories to tags
        _.extend publication,
          tags: [publication.source]
          # TODO: Just temporary, remove
          owner: 'carl-sagan'

        id = Publications.insert publication
        counter++
        console.log "Imported ##{ counter }: #{ id }"

    # Cacche and process only the first 10 publications
    Publications.find({processed: {$ne: true}}, {limit: 10}).forEach (publication) ->
      if not publication.cached
        console.log "Caching #{ publication._id } from #{ publication.url() }"
        file = publication.cache()

      console.log "Processing #{ publication._id }"
      publication.process file # Nothing wrong if file is not defined, process will open it itself

    console.log "Done"
