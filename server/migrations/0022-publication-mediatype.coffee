class Migration extends Document.MinorMigration
  name: "Adding mediaType field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, Meteor.bindEnvironment (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema, mediaType: {$exists: false}}, {$set: {mediaType: 'pdf'}}, {multi: true}, Meteor.bindEnvironment (error, count) =>
        return callback error if error
        Meteor.bindEnvironment(=>
          Storage.rename 'pdf', 'publication' if Storage.exists 'pdf'
          super db, collectionName, currentSchema, newSchema, callback
        , callback)()
      , callback
    , callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, Meteor.bindEnvironment (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {mediaType: ''}}, {multi: true}, Meteor.bindEnvironment (error, count) =>
        return callback error if error
        Meteor.bindEnvironment(=>
          Storage.rename 'publication', 'pdf' if Storage.exists 'publication'
          super db, collectionName, currentSchema, oldSchema, callback
        , callback)()
      , callback
    , callback

Publication.addMigration new Migration()
