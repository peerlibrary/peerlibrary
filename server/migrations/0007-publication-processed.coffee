class Migration extends Document.MajorMigration
  name: "Converting processed field to a timestamp"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema}, {_schema: 1, processed: 1}, (document) =>
      return if _.isDate document.processed

      # If true value
      if document.processed
        count += collection.update document, {$set: {processed: moment.utc().toDate(), _schema: newSchema}}
      else
        count += collection.update document, {$unset: {processed: ''}, $set: {_schema: newSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema}, {_schema: 1, processed: 1}, (document) =>
      if _.isDate document.processed
        count += collection.update document, {$set: {processed: true, _schema: oldSchema}}
      else
        count += collection.update document, {$unset: {processed: ''}, $set: {_schema: oldSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Publication.addMigration new Migration()
