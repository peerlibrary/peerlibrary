class @ProcessPublicationJob extends Job
  enqueueOptions: (options) =>
    options = super

    _.defaults options,
      priority: 'medium'

  run: =>
    publication = @data.publication

    # Publication stored in job's data is just an ID, so let's fetch the whole document first
    publication.refresh()

    publication.process @

    return # Return nothing

Job.addJobClass ProcessPublicationJob

class @ProcessPublicationsJob extends Job
  enqueueOptions: (options) =>
    options = super

    _.defaults options,
      priority: 'high'

  run: =>
    thisJob = @getQueueJob()
    count = 0

    query =
      cached:
        $exists: true

    unless @data.all
      query.processed =
        $exists: false

    Publication.documents.find(
      query
    ,
      fields:
        _id: 1
      transform: null
    ).forEach (publication) =>
      count++ if new ProcessPublicationJob(publication: publication).enqueue(
        skipIfExisting: true
        depends: thisJob # To create a relation
      )

    count: count

Job.addJobClass ProcessPublicationsJob
