class Migration extends Document.PatchMigration
  name: "Reprocessing publications with jobs"

  forward: (document, collection, currentSchema, newSchema) =>
    update =
      $unset:
        processed: ''
      $set:
        _schema: newSchema

    count = collection.update {_schema: currentSchema}, update, {multi: true}

    counts = super
    counts.migrated += count
    counts.all += count

    new ProcessPublicationsJob(all: true).enqueue() if counts.migrated

    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    update =
      $unset:
        processed: ''
      $set:
        _schema: oldSchema

    count = collection.update {_schema: currentSchema}, update, {multi: true}

    counts = super
    counts.migrated += count
    counts.all += count

    @updateAll document, collection, currentSchema, oldSchema

    counts

Publication.addMigration new Migration()
