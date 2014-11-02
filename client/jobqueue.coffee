Tracker.autorun ->
  if Session.get 'publicationJobsId'
    Meteor.subscribe 'publication-by-id', Session.get 'publicationJobsId'
    Meteor.subscribe 'jobs-by-publication', Session.get 'publicationJobsId'

Template.publicationJobs.helpers
  jobqueue: ->
    JobQueue.documents.find
      'data.publication._id': Session.get 'publicationJobsId'
    ,
      sort: [
        ['updated', 'desc']
      ]
      transform: null # So that publication subdocument does not get client-only attributes like _pages and _highlighter

  publication: ->
    Publication.documents.findOne Session.get 'publicationJobsId'

  publicationId: ->
    Session.get 'publicationJobsId'
