class Migration extends Document.PatchMigration
  name: "Adding missing values for createdAt and updatedAt fields"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection 'users', (error, usersCollection) =>
      return callback error if error

      db.collection collectionName, (error, collection) =>
        return callback error if error

        cursor = collection.find {_schema: currentSchema, $or: [{createdAt: {$exists: false}}, {updatedAt: {$exists: false}}]}, {'user._id': 1, createdAt: 1, updatedAt: 1}
        document = null
        async.doWhilst (callback) =>
          cursor.nextObject (error, doc) =>
            return callback error if error
            document = doc
            return callback null unless document

            if document.createdAt and not document.updatedAt
              collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: document.createdAt}}, (error, count) =>
                return callback error if error
                callback null
            else if document.user?._id
              usersCollection.findOne {_id: document.user._id}, {createdAt: 1}, (error, user) =>
                return callback error if error
                assert user?.createdAt
                collection.update {_schema: currentSchema, _id: document._id, createdAt: {$exists: false}}, {$set: {createdAt: user.createdAt}}, (error, count) =>
                  collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: user.createdAt}}, (error, count) =>
                    return callback error if error
                    callback null
            else
              createdAt = moment.utc().toDate()
              collection.update {_schema: currentSchema, _id: document._id, createdAt: {$exists: false}}, {$set: {createdAt: createdAt}}, (error, count) =>
                collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: createdAt}}, (error, count) =>
                  return callback error if error
                  callback null
        ,
          =>
            document
        ,
          (error) =>
            return callback error if error
            super db, collectionName, currentSchema, newSchema, callback

Person.addMigration new Migration()
