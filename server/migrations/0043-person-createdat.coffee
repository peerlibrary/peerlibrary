class Migration extends Document.PatchMigration
  name: "Adding missing values for createdAt, updatedAt, and lastActivity fields"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0
    usersCollection = new DirectCollection 'users'

    collection.findEach {_schema: currentSchema, $or: [{createdAt: {$exists: false}}, {updatedAt: {$exists: false}}, {lastActivity: {$exists: false}}]}, {'user._id': 1, createdAt: 1, updatedAt: 1, lastActivity: 1}, (document) =>
      if document.createdAt
        c = collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: (document.lastActivity or document.createdAt)}}
        c += collection.update {_schema: currentSchema, _id: document._id, lastActivity: {$exists: false}}, {$set: {lastActivity: (document.updatedAt or document.createdAt)}}

      else if document.user?._id
        user = usersCollection.findOne {_id: document.user._id}, {createdAt: 1}
        assert user?.createdAt
        c = collection.update {_schema: currentSchema, _id: document._id, createdAt: {$exists: false}}, {$set: {createdAt: user.createdAt}}
        c += collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: (document.lastActivity or user.createdAt)}}
        c += collection.update {_schema: currentSchema, _id: document._id, lastActivity: {$exists: false}}, {$set: {lastActivity: (document.updatedAt or user.createdAt)}}

      else
        createdAt = moment.utc().toDate()
        c = collection.update {_schema: currentSchema, _id: document._id, createdAt: {$exists: false}}, {$set: {createdAt: createdAt}}
        c += collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: (document.lastActivity or createdAt)}}
        c += collection.update {_schema: currentSchema, _id: document._id, lastActivity: {$exists: false}}, {$set: {lastActivity: (document.updatedAt or createdAt)}}

      count += if c > 0 then 1 else 0

    counts = super
    counts.migrated += count
    # We do not increase all because we are not modifying _schema above
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    count = collection.update {_schema: currentSchema}, {$unset: {lastActivity: ''}, $set: {_schema: oldSchema}}, {multi: true}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Person.addMigration new Migration()
