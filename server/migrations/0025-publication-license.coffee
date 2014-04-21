class Migration extends Document.MinorMigration
  name: "Adding license field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema, license: {$exists: false}, source: 'arXiv'}, {$set: {license: 'arXiv'}}, {multi: true}, (error, count) =>
        return callback error if error
        collection.update {_schema: currentSchema, license: {$exists: false}, source: 'FSM'}, {$set: {license: 'https://creativecommons.org/licenses/by-nc-sa/3.0/us/'}}, {multi: true}, (error, count) =>
          return callback error if error
          super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {license: ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Publication.addMigration new Migration()
