populateUpdatedAt = (db, collectionName, currentSchema, newSchema, callback) ->
  db.collection collectionName, (error, collection) =>
    return callback error if error

    cursor = collection.find {_schema: currentSchema, $or: [{createdAt: {$exists: false}}, {updatedAt: {$exists: false}}]}, {createdAt: 1, updatedAt: 1}
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
      callback

class Migration extends Document.PatchMigration
  name: "Adding missing values for createdAt and updatedAt fields"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    populateUpdatedAt.call @, db, collectionName, currentSchema, newSchema, (error) =>
      return callback error if error
      super db, collectionName, currentSchema, newSchema, callback

class MinorMigration extends Document.MinorMigration
  name: "Adding updatedAt field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    populateUpdatedAt.call @, db, collectionName, currentSchema, newSchema, (error) =>
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
