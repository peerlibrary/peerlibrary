class Migration extends Document.PatchMigration
  # In the past we stored link between a highlight and an annotation in the
  # document independently from the body. Now we require that each such link
  # has an <a/> tag in the body, so we add dummy links here if such is missing.
  name: "Adding missing reference links to body field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      # At this stage only highlight referneces should exist, others were not yet possible through the interface
      cursor = collection.find {_schema: currentSchema, body: {$exists: true}}, {body: 1, 'references.highlights': 1}
      document = null
      async.doWhilst (callback) =>
        cursor.nextObject (error, doc) =>
          return callback error if error
          document = doc
          return callback null unless document

          async.eachSeries (document.references?.highlights or []), (highlight, callback) =>
            assert highlight._id

            # We do not want to depend on our parsing code as it might change through time and
            # we want migrations to always work. So let's do a simple check here, checking if
            # highlight's ID appears in the body as a string, assuming that is a link.
            return callback null if new RegExp(highlight._id).test document.body

            newBody = "#{ document.body }<p>(See <a href=\"/h/#{ highlight._id }\">h:#{ highlight._id }</a>)</p>"

            collection.update {_schema: currentSchema, _id: document._id, body: document.body}, {$set: {body: newBody}}, (error, count) =>
              return callback error if error
              document.body = newBody
              callback null
          ,
            (error) =>
              return callback error if error
              callback null
      ,
        =>
          document
      ,
        (error) =>
          return callback error if error
          super db, collectionName, currentSchema, newSchema, callback

Annotation.addMigration new Migration()
