getImportingFilename = (document, index) ->
  'publication' + Storage._path.sep + 'tmp' + Storage._path.sep + document.importing[index].importingId + '.pdf'

class Migration extends Document.MinorMigration
  name: "Adding createdAt and updatedAt to importing array"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error

      cursor = collection.find {_schema: currentSchema, 'importing.createdAt': {$exists: false}, 'importing.updatedAt': {$exists: false}}, {cached: 1, importing: 1}
      document = null
      async.doWhilst (callback) =>
        cursor.nextObject (error, doc) =>
          return callback error if error
          document = doc
          return callback null unless document

          updateQuery =
            $set: {}

          for importing, i in document.importing or []
            continue if importing.createdAt and importing.updatedAt

            filename = getImportingFilename document, i
            try
              timestamp = Storage.lastModificationTime filename
              updateQuery.$set["importing.#{ i }.createdAt"] = timestamp unless importing.createdAt
              updateQuery.$set["importing.#{ i }.updatedAt"] = timestamp unless importing.updatedAt
            catch error
              # We ignore any error, files might not exist anymore

          # It is OK if updateQuery stays empty, update query does
          # not do anything then, but code logic is simpler

          collection.update {_schema: currentSchema, _id: document._id, 'importing.createdAt': {$exists: false}, 'importing.updatedAt': {$exists: false}}, updateQuery, (error, count) =>
            return callback error if error

            if document.cached
              # We have the whole file cached, so remove all other partially uploaded files, if there are any
              for importing, i in document.importing or []
                filename = getImportingFilename document, i
                try
                  Storage.remove filename
                catch error
                  # We ignore any error when removing partially uploaded files

            callback null
      ,
        =>
          document
      ,
        (error) =>
          return callback error if error
          super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {'importing.createdAt': '', 'importing.updatedAt': ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Publication.addMigration new Migration()
