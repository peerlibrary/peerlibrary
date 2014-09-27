# Original migration for renaming (0017) was not doing anything, so we fixed it
# and have it again here, so that it runs again for fields which were not migrated.

class Migration extends Document.MajorMigration
  name: "Renaming temporaryFilename field to importingId, take 2"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, 'importing.temporaryFilename': {$exists: true}}, {importing: 1}, (document) =>
      updateQuery =
        $set:
          _schema: newSchema
        $unset: {}

      for importing, i in document.importing or []
        continue if importing.importingId or not importing.temporaryFilename

        updateQuery.$set["importing.#{ i }.importingId"] = importing.temporaryFilename
        updateQuery.$unset["importing.#{ i }.temporaryFilename"] = ''

      count += collection.update {_schema: currentSchema, _id: document._id, importing: document.importing}, updateQuery

    counts = super
    counts.migrated += count
    counts.all += count
    counts

  # We don't define backward migration because this should be handled by the original migration.
  # That is the proper time when the code expects temporaryFilename and not importingId.

Publication.addMigration new Migration()
