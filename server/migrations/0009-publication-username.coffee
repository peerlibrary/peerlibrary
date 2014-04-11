class Migration extends Document.MinorMigration
  name: "Adding user.username to Publication's authors"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    @updateAll()
    super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {'authors.user': ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Publication.addMigration new Migration()
