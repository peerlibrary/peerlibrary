do -> # To not pollute the namespace
  Meteor.startup ->
    if Publications.find().count() == 0
      console.log "Population database with sample data"

      publications = [
        _id: 'yJWgdtENibW2Z3s5W'
        title: 'Foobar'
        originalUrl: 'https://github.com/mozilla/pdf.js/raw/master/web/compressed.tracemonkey-pldi-09.pdf'
        downloaded: false
        processed: false
      ]

      for publication in publications
        Publications.insert publication
