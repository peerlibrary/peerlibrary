# Original migration for renaming (0017) was not doing anything, so we fixed it,
# added it again as 0063, but now we have a migration (0041) which depends on it
# again here, so that it runs again with all fields really migrated.

getImportingFilename = (document, index) ->
  assert document.importing[index].importingId

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

  # We don't define backward migration because this should be handled by the original migration.
  # That is the proper time when the code doesn't expect createdAt or updatedAt.

Publication.addMigration new Migration()
