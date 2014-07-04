populate = (db, collectionName, currentSchema, newSchema, callback) ->
  db.collection collectionName, (error, collection) =>
    return callback error if error

    cursor = collection.find {_schema: currentSchema, $or: [{createdAt: {$exists: false}}, {updatedAt: {$exists: false}}, {lastActivity: {$exists: false}}]}, {createdAt: 1, updatedAt: 1, lastActivity: 1}
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
      callback

class Migration extends Document.PatchMigration
  name: "Adding missing values for createdAt, updatedAt, and lastActivity fields"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    populate.call @, db, collectionName, currentSchema, newSchema, (error) =>
      return callback error if error
      super db, collectionName, currentSchema, newSchema, callback

class MinorMigration extends Document.MinorMigration
  name: "Adding missing values for updatedAt and lastActivity fields"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    populate.call @, db, collectionName, currentSchema, newSchema, (error) =>
      return callback error if error
      super db, collectionName, currentSchema, newSchema, callback

# User is special case because we are also adding updatedAt field itself
User.addMigration new MinorMigration()

Annotation.addMigration new Migration()
Collection.addMigration new Migration()
Comment.addMigration new Migration()
Group.addMigration new Migration()
Highlight.addMigration new Migration()
# Person was migrated in previous migration
Publication.addMigration new Migration()
Tag.addMigration new Migration()
Url.addMigration new Migration()
