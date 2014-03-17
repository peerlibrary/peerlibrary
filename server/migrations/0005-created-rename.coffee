class Migration extends Document.MinorMigration
  name: "Renaming created and updated fields to createdAt and updatedAt"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$rename: {created: 'createdAt', updated: 'updatedAt'}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$rename: {createdAt: 'created', updatedAt: 'updated'}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Annotation.addMigration new Migration()
Highlight.addMigration new Migration()
Person.addMigration new Migration()
Publication.addMigration new Migration()
