class Migration extends Document.MinorMigration
  name: "Adding fullText field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    @updateAll()
    super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {fullText: ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Publication.addMigration new Migration()
