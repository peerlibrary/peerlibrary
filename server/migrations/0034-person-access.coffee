class Migration extends Document.MinorMigration
  name: "Adding maintainerPersons, maintainerGroups, adminPersons, adminGroups fields"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema, maintainerPersons: {$exists: false}, maintainerGroups: {$exists: false}, adminGroups: {$exists: false}}, {$set: {maintainerPersons: [], maintainerGroups: [], adminGroups: []}}, {multi: true}, (error, count) =>
        return callback error if error

        cursor = collection.find {_schema: currentSchema, adminPersons: {$exists: false}}, {_id: 1}
        document = null
        async.doWhilst (callback) =>
          cursor.nextObject (error, doc) =>
            return callback error if error
            document = doc
            return callback null unless document

            collection.update {_schema: currentSchema, _id: document._id, adminPersons: {$exists: false}}, {$set: {adminPersons: [_id: document._id]}}, (error, count) =>
              return callback error if error
              callback null
        ,
          =>
            document
        ,
          (error) =>
            return callback error if error
            super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {maintainerPersons: '', maintainerGroups: '', adminPersons: '', adminGroups: ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Person.addMigration new Migration()
