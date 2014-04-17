class Migration extends Document.MinorMigration
  name: "Adding members and membersCount fields"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema, members: {$exists: false}}, {$set: {members: []}}, {multi: true}, (error, count) =>
        return callback error if error
        @updateAll()
        super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {members: '', membersCount: ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Group.addMigration new Migration()
