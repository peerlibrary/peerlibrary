populate = (document, collection, currentSchema, newSchema) ->
  count = 0

  collection.findEach {_schema: currentSchema, $or: [{createdAt: {$exists: false}}, {updatedAt: {$exists: false}}, {lastActivity: {$exists: false}}]}, {createdAt: 1, updatedAt: 1, lastActivity: 1}, (document) ->
    if document.createdAt
      c = collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: (document.lastActivity or document.createdAt)}}
      c += collection.update {_schema: currentSchema, _id: document._id, lastActivity: {$exists: false}}, {$set: {lastActivity: (document.updatedAt or document.createdAt)}}

    else
      createdAt = moment.utc().toDate()
      c = collection.update {_schema: currentSchema, _id: document._id, createdAt: {$exists: false}}, {$set: {createdAt: createdAt}}
      c += collection.update {_schema: currentSchema, _id: document._id, updatedAt: {$exists: false}}, {$set: {updatedAt: (document.lastActivity or createdAt)}}
      c += collection.update {_schema: currentSchema, _id: document._id, lastActivity: {$exists: false}}, {$set: {lastActivity: (document.updatedAt or createdAt)}}

    count += if c > 0 then 1 else 0

  count

class Migration extends Document.PatchMigration
  name: "Adding missing values for createdAt, updatedAt, and lastActivity fields"

  forward: (document, collection, currentSchema, newSchema) =>
    count = populate document, collection, currentSchema, newSchema

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

class MinorMigration extends Document.MinorMigration
  name: "Adding missing values for updatedAt and lastActivity fields"

  forward: (document, collection, currentSchema, newSchema) =>
    count = populate document, collection, currentSchema, newSchema

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
