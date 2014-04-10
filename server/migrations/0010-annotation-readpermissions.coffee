class Migration extends Document.MinorMigration
  name: "Adding access, readPersons, and readGroups fields to Annotation"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$set: {access: Annotation.ACCESS.PUBLIC}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {access: ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Annotation.addMigration new Migration()
