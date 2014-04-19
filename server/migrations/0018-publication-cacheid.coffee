getOldFilename = (document) ->
  if document.source is 'arXiv'
    'pdf' + Storage._path.sep + 'arxiv' + Storage._path.sep + document.foreignId + '.pdf'
  else
    # We use import also as a fallback for any unsupported document source.
    # This allows us to go first backward in migrations and then again forward.
    'pdf' + Storage._path.sep + 'import' + Storage._path.sep + document._id + '.pdf'

getNewFilename = (cachedId) ->
  'pdf' + Storage._path.sep + 'cache' + Storage._path.sep + cachedId + '.pdf'

class Migration extends Document.MajorMigration
  name: "Adding cachedId field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, Meteor.bindEnvironment (error, collection) =>
      return callback error if error
      cursor = collection.find {_schema: currentSchema, cached: {$exists: true}, cachedId: {$exists: false}}, {source: 1, foreignId: 1}
      document = null
      async.doWhilst Meteor.bindEnvironment((callback) =>
          cursor.nextObject Meteor.bindEnvironment (error, doc) =>
            return callback error if error
            document = doc
            return callback null unless document

            oldFilename = getOldFilename document

            cachedId = Random.id()
            newFilename = getNewFilename cachedId

            collection.update {_schema: currentSchema, _id: document._id, cachedId: {$exists: false}}, {$set: {cachedId: cachedId}}, Meteor.bindEnvironment (error, count) =>
              return callback error if error
              return callback null unless count

              Meteor.bindEnvironment(=>
                if document.source is 'arXiv'
                  Storage.link oldFilename, newFilename
                else
                  Storage.rename oldFilename, newFilename
                callback null
              , callback)()
            , callback
          , callback
        , callback)
      ,
        =>
          document
      ,
        Meteor.bindEnvironment (error) =>
          return callback error if error
          super db, collectionName, currentSchema, newSchema, callback
        , callback
    , callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, Meteor.bindEnvironment (error, collection) =>
      return callback error if error
      cursor = collection.find {_schema: currentSchema, cached: {$exists: true}, cachedId: $exists: true}, {cachedId: 1, source: 1, foreignId: 1}
      document = null
      async.doWhilst Meteor.bindEnvironment((callback) =>
          cursor.nextObject Meteor.bindEnvironment (error, doc) =>
            return callback error if error
            document = doc
            return callback null unless document

            oldFilename = getOldFilename document
            newFilename = getNewFilename document.cachedId

            collection.update {_schema: currentSchema, _id: document._id, cachedId: document.cachedId}, {$unset: {cachedId: ''}}, Meteor.bindEnvironment (error, count) =>
              return callback error if error
              return callback null unless count

              Meteor.bindEnvironment(=>
                if document.source is 'arXiv'
                  Storage.remove newFilename
                else
                  Storage.rename newFilename, oldFilename
                callback null
              , callback)()
            , callback
          , callback
        , callback)
      ,
        =>
          document
      ,
        Meteor.bindEnvironment (error) =>
          return callback error if error
          super db, collectionName, currentSchema, oldSchema, callback
        , callback
    , callback

Publication.addMigration new Migration()
