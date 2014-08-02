# In addition to verifying links between files stored under foreign filename and
# cached filename, we for now provide a way for easy caching of sample publications
# so that developers can easily bootstrap their local development instance
# TODO: Think how to make a better sample which would contain both metadata and content
class @CheckCacheJob extends Job
  enqueueOptions: (options) =>
    options = super

    _.defaults options,
      priority: 'medium'

  run: =>
    # Publication stored in job's data is just an ID, so let's fetch the whole document first
    @publication.refresh()

    if @publication.cached
      @logInfo "Publication is already cached"
      return

    if not Storage.exists @publication.cachedFilename()
      if not @publication.foreignFilename()
        @logInfo "Publication has no foreign source"
        return

      else if Storage.exists @publication.foreignFilename()
        @logInfo "Linking: #{ @publication.foreignFilename() } -> #{ @publication.cachedFilename() }"

        Storage.link @publication.foreignFilename(), @publication.cachedFilename()
        assert Storage.exists @publication.cachedFilename()

      else
        if @publication.foreignUrl
          @logInfo "Caching file from '#{ @publication.foreignUrl }': #{ @publication.foreignFilename() } -> #{ @publication.cachedFilename() }"
          url = @publication.foreignUrl
        else
          @logInfo "Caching file from the central server: #{ @publication.foreignFilename() } -> #{ @publication.cachedFilename() }"
          url = "http://stage.peerlibrary.org#{ @publication.storageForeignUrl() }"

        file = HTTP.get url,
          timeout: 10000 # ms
          encoding: null # Transfer files as binary data

        Storage.save @publication.foreignFilename(), file.content
        assert Storage.exists @publication.foreignFilename()
        Storage.link @publication.foreignFilename(), @publication.cachedFilename()
        assert Storage.exists @publication.cachedFilename()

    if not @publication.sha256
      @logInfo "Computing SHA256 hash"

      pdfContent = Storage.open @publication.cachedFilename()
      hash = new Crypto.SHA256()
      hash.update pdfContent
      @publication.sha256 = hash.finalize()

    @publication.cached = moment.utc().toDate()
    Publication.documents.update @publication._id,
      $set:
        cached: @publication.cached
        sha256: @publication.sha256

    return # Return nothing

Job.addJobClass CheckCacheJob

class @CacheSyncJob extends Job
  enqueueOptions: (options) =>
    options = super

    _.defaults options,
      priority: 'high'

  run: =>
    count = 0

    Publication.documents.find(
      cached:
        $exists: false
      source:
        $in: Publication.foreignSources
    ,
      fields:
        _id: 1
    ).forEach (publication) =>
      new CheckCacheJob(publication: publication).enqueue()
      count++

    count: count

Job.addJobClass CacheSyncJob
