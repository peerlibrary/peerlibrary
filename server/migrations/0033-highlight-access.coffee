class Migration extends Document.MajorMigration
  name: "Removing access, readPersons, readGroups fields"

  forward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {access: '', readPersons: '', readGroups: ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

  backward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema, access: {$exists: false}, readPersons: {$exists: false}, readGroups: {$exists: false}}, {$set: {access: ACCESS.PUBLIC, readPersons: [], readGroups: []}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, newSchema, callback

Highlight.addMigration new Migration()
