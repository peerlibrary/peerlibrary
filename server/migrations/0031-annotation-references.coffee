class Migration extends Document.MajorMigration
  name: "Converting highlights field to references field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      cursor = collection.find {_schema: currentSchema, highlights: {$exists: true}, references: {$exists: false}}, {highlights: 1}
      document = null
      async.doWhilst (callback) =>
        cursor.nextObject (error, doc) =>
          return callback error if error
          document = doc
          return callback null unless document

          collection.update {_schema: currentSchema, _id: document._id, highlights: document.highlights, references: {$exists: false}}, {$unset: {highlights: ''}, $set: {references: {highlights: document.highlights, annotations: [], publications: [], persons: [], tags: []}}}, (error, count) =>
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
      cursor = collection.find {_schema: currentSchema, highlights: {$exists: false}, references: $exists: true}, {references: 1}
      document = null
      async.doWhilst (callback) =>
        cursor.nextObject (error, doc) =>
          return callback error if error
          document = doc
          return callback null unless document

          collection.update {_schema: currentSchema, _id: document._id, references: document.references}, {$unset: {references: ''}, $set: {highlights: (document.references?.highlights or [])}}, (error, count) =>
            return callback error if error
            callback null
      ,
        =>
          document
      ,
        (error) =>
          return callback error if error
          super db, collectionName, currentSchema, oldSchema, callback

Annotation.addMigration new Migration()
