Publications = new Meteor.Collection 'publications'

do -> # To not pollute the namespace
  Meteor.publish 'get-publication', (publicationId) ->
    self = this
    uuid = Meteor.uuid()

    self.added 'get-publication', uuid, {message: "Opening publication"}
    self.ready()

    require = __meteor_bootstrap__.require
    Future = require 'fibers/future'

    sleep = (ms) ->
      future = new Future
      Meteor.setTimeout ->
        future.return()
      , ms
      future

    sleep(1000).wait()

    self.changed 'get-publication', uuid, {message: "Downloading publication"}

    sleep(1000).wait()

    self.changed 'get-publication', uuid, {message: undefined, url: 'https://github.com/mozilla/pdf.js/raw/master/web/compressed.tracemonkey-pldi-09.pdf'}
