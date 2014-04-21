class Migration extends Document.MinorMigration
  name: "Adding inside field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema, inside: {$exists: false}}, {$set: {inside: []}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {inside: ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Annotation.addMigration new Migration()
