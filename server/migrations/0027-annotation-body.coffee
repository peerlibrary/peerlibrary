class Migration extends Document.MajorMigration
  name: "Changing body field to HTML"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      cursor = collection.find {_schema: currentSchema, body: {$exists: true}}, {body: 1}
      document = null
      async.doWhilst (callback) =>
        cursor.nextObject (error, doc) =>
          return callback error if error
          document = doc
          return callback null unless document

          return callback null if /^<[^>]+>.*<[^>]+>$/.test document.body.trim()

          collection.update {_schema: currentSchema, _id: document._id, body: document.body}, {$set: {body: "<p>#{ document.body }</p>"}}, (error, count) =>
            return callback error if error
            callback null
      ,
        =>
          document
      ,
        (error) =>
          return callback error if error
          super db, collectionName, currentSchema, newSchema, callback

Annotation.addMigration new Migration()
