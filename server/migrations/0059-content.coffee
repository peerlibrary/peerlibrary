class Migration extends Document.PatchMigration
  name: "Cleaning HTML in body field"

  constructor: (@cleanHTML) ->
    super

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, body: {$exists: true}}, {body: 1}, (document) =>
      newBody = @cleanHTML document.body
      count += collection.update {_schema: currentSchema, _id: document._id, body: document.body}, {$set: {body: newBody, _schema: newSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Annotation.addMigration new Migration cleanBlockHTML
Comment.addMigration new Migration cleanInlineHTML
