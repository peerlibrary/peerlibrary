class @NormalizePublicationJob extends Job
  enqueueOptions: (options) =>
    options = super

    _.defaults options,
      priority: 'medium'

  run: =>
    if Meteor.settings.ghostScript
      publication = @data.publication

      path = Storage._fullPath(publication.cachedFilename()).split Storage._path.sep
      path.pop()
      path = path.join Storage._path.sep

      fileId = Random.id()

      result = Meteor.execFileSync 'gs', ['-sDEVICE=pdfwrite', '-dNOPAUSE', '-dQUIET', '-dBATCH', '-dFastWebView=true', '-dUseCIEColor', '-sProcessColorModel=DeviceCMYK', "-sOutputFile=#{path}/#{fileId}.pdf", Storage._fullPath publication.cachedFilename()]

      if result.success # What should happen on failure?
        pdf = Storage.open publication.cachedFilename fileId

        hash = new Crypto.SHA256()
        hash.update pdf
        sha256 = hash.finalize()

        publication.files.push
          fileId: fileId
          createdAt: moment.utc().toDate()
          updatedAt: moment.utc().toDate()
          sha256: sha256
          mediaType: 'pdf'
          type: 'normalized-gs'
          logs: result

    return # Return nothing

Job.addJobClass NormalizePublicationJob

class @NormalizePublicationsJob extends Job
  enqueueOptions: (options) =>
    options = super

    _.defaults options,
      priority: 'high'

  run: =>
    count = 0

    query =
      files:
        $elemMatch:
          type:
            $ne: 'normalized-gs'

    Publication.documents.find(query).forEach (publication, i) =>
      count++ if new NormalizePublicationJob(publication: publication).enqueue(skipIfExisting: true)

    count: count

Job.addJobClass NormalizePublicationsJob
