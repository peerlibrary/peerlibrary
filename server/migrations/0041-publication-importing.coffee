getImportingFilename = (document, index) ->
  'publication' + Storage._path.sep + 'tmp' + Storage._path.sep + document.importing[index].importingId + '.pdf'

class Migration extends Document.MinorMigration
  name: "Adding createdAt and updatedAt to importing array"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, 'importing.createdAt': {$exists: false}, 'importing.updatedAt': {$exists: false}}, {cached: 1, importing: 1}, (document) =>
      updateQuery =
        $set:
          _schema: newSchema

      for importing, i in document.importing or []
        continue if importing.createdAt and importing.updatedAt

        filename = getImportingFilename document, i
        try
          timestamp = Storage.lastModificationTime filename
          updateQuery.$set["importing.#{ i }.createdAt"] = timestamp unless importing.createdAt
          updateQuery.$set["importing.#{ i }.updatedAt"] = timestamp unless importing.updatedAt
        catch error
          # We ignore any error, files might not exist anymore

      count += collection.update {_schema: currentSchema, _id: document._id, 'importing.createdAt': {$exists: false}, 'importing.updatedAt': {$exists: false}}, updateQuery

      if document.cached
        # We have the whole file cached, so remove all other partially uploaded files, if there are any,
        # but we leave importing entries in the database for now so that users have their filenames displayed
        for importing, i in document.importing or []
          filename = getImportingFilename document, i
          try
            Storage.remove filename
          catch error
            # We ignore any error when removing partially uploaded files

    counts = super
    counts.migrated += count
    counts.all += count
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    count = collection.update {_schema: currentSchema}, {$unset: {'importing.createdAt': '', 'importing.updatedAt': ''}, $set: {_schema: oldSchema}}, {multi: true}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Publication.addMigration new Migration()
