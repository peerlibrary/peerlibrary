if Meteor.isServer
  class @JobCollection extends JobCollection
    scrub: (job) ->
      # We have to make a plain object (our documents go through PeerDB transform)
      # and without _schema field which is added to all PeerDB documents
      _.omit job, '_schema', 'constructor'

class @JobQueue extends Document
  # TODO: Describe

  @Meta
    name: 'JobQueue'
    collection: new JobCollection 'JobQueue',
      noCollectionSuffix: true
