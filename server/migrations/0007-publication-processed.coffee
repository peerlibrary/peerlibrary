class Migration extends Document.MajorMigration
  name: "Converting Publication's processed field to a timestamp"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      cursor = collection.find {_schema: currentSchema}, {processed: 1}
      document = null
      async.doWhilst (callback) =>
        cursor.nextObject (error, doc) =>
          return callback error if error
          document = doc
          return callback null unless document

          return callback null if _.isDate document.processed

          if document.processed
            collection.update {_schema: currentSchema, _id: document._id, processed: document.processed}, {$set: {processed: moment.utc().toDate()}}, (error, count) =>
              return callback error if error

              callback null
          else
            collection.update {_schema: currentSchema, _id: document._id, processed: document.processed}, {$unset: {processed: ''}}, (error, count) =>
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
      cursor = collection.find {_schema: currentSchema}, {processed: 1}
      document = null
      async.doWhilst (callback) =>
        cursor.nextObject (error, doc) =>
          return callback error if error
          document = doc
          return callback null unless document

          if _.isDate document.processed
            collection.update {_schema: currentSchema, _id: document._id, processed: document.processed}, {$set: {processed: true}}, (error, count) =>
              return callback error if error

              callback null
          else
            collection.update {_schema: currentSchema, _id: document._id, processed: document.processed}, {$unset: {processed: ''}}, (error, count) =>
              return callback error if error

              callback null
      ,
        =>
          document
      ,
        (error) =>
          return callback error if error
          super db, collectionName, currentSchema, oldSchema, callback

Publication.addMigration new Migration()
