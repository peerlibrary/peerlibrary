class Migration extends Document.PatchMigration
  name: "Adding missing values for createdAt, updatedAt, and lastActivity fields"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection 'users', (error, usersCollection) =>
      return callback error if error

      db.collection collectionName, (error, collection) =>
        return callback error if error

        cursor = collection.find {_schema: currentSchema, $or: [{createdAt: {$exists: false}}, {updatedAt: {$exists: false}}, {lastActivity: {$exists: false}}]}, {'user._id': 1, createdAt: 1, updatedAt: 1, lastActivity: 1}
        document = null
        async.doWhilst (callback) =>
          cursor.nextObject (error, doc) =>
            return callback error if error
            document = doc
            return callback null unless document

            if document.createdAt
              collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: (document.lastActivity or document.createdAt)}}, (error, count) =>
                collection.update {_schema: currentSchema, _id: document._id, lastActivity: {$exists: false}}, {$set: {lastActivity: (document.updatedAt or document.createdAt)}}, (error, count) =>
                  return callback error if error
                  callback null
            else if document.user?._id
              usersCollection.findOne {_id: document.user._id}, {createdAt: 1}, (error, user) =>
                return callback error if error
                assert user?.createdAt
                collection.update {_schema: currentSchema, _id: document._id, createdAt: {$exists: false}}, {$set: {createdAt: user.createdAt}}, (error, count) =>
                  collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: (document.lastActivity or user.createdAt)}}, (error, count) =>
                    collection.update {_schema: currentSchema, _id: document._id, lastActivity: {$exists: false}}, {$set: {lastActivity: (document.updatedAt or user.createdAt)}}, (error, count) =>
                      return callback error if error
                      callback null
            else
              createdAt = moment.utc().toDate()
              collection.update {_schema: currentSchema, _id: document._id, createdAt: {$exists: false}}, {$set: {createdAt: createdAt}}, (error, count) =>
                collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: (document.lastActivity or createdAt)}}, (error, count) =>
                  collection.update {_schema: currentSchema, _id: document._id, lastActivity: {$exists: false}}, {$set: {lastActivity: (document.updatedAt or createdAt)}}, (error, count) =>
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
      collection.update {_schema: currentSchema}, {$unset: {lastActivity: ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Person.addMigration new Migration()
