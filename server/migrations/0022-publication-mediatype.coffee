class Migration extends Document.MinorMigration
  name: "Adding mediaType field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema, mediaType: {$exists: false}}, {$set: {mediaType: 'pdf'}}, {multi: true}, (error, count) =>
        return callback error if error
        Storage.rename 'pdf', 'publication'
        super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {mediaType: ''}}, {multi: true}, (error, count) =>
        return callback error if error
        Storage.rename 'publication', 'pdf'
        super db, collectionName, currentSchema, oldSchema, callback

Publication.addMigration new Migration()
