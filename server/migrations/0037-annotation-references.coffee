class Migration extends Document.MinorMigration
  name: "Adding groups, collections, comments, and urls to references field"

  forward: (db, collectionName, currentSchema, newSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema, 'references.groups': {$exists: false}, 'references.collections': {$exists: false}, 'references.comments': {$exists: false}, 'references.urls': {$exists: false}}, {$set: {'references.groups': [], 'references.collections': [], 'references.comments': [], 'references.urls': []}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, newSchema, callback

  backward: (db, collectionName, currentSchema, oldSchema, callback) =>
    db.collection collectionName, (error, collection) =>
      return callback error if error
      collection.update {_schema: currentSchema}, {$unset: {'references.groups': '', 'references.collections': '', 'references.comments': '', 'references.urls': ''}}, {multi: true}, (error, count) =>
        return callback error if error
        super db, collectionName, currentSchema, oldSchema, callback

Annotation.addMigration new Migration()
