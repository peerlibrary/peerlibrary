class Migration extends Document.MajorMigration
  name: "Changing body field to HTML"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, body: {$exists: true}}, {_schema: 1, body: 1}, (document) =>
      return if /^<[^>]+>.*<[^>]+>$/.test document.body.trim()

      count += collection.update document, {$set: {body: "<p>#{ document.body }</p>", _schema: newSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Annotation.addMigration new Migration()
