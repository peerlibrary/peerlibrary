class Migration extends Document.MinorMigration
  name: "Adding maintainerPersons, maintainerGroups, adminPersons, adminGroups fields"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, maintainerPersons: {$exists: false}, maintainerGroups: {$exists: false}, adminPersons: {$exists: false}, adminGroups: {$exists: false}}, {author: 1}, (document) =>
      count += collection.update {_schema: currentSchema, maintainerPersons: {$exists: false}, maintainerGroups: {$exists: false}, adminPersons: {$exists: false}, adminGroups: {$exists: false}}, {$set: {maintainerPersons: [], maintainerGroups: [], adminPersons: [_id: document.author._id], adminGroups: [], _schema: newSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    count = collection.update {_schema: currentSchema}, {$unset: {maintainerPersons: '', maintainerGroups: '', adminPersons: '', adminGroups: ''}, $set: {_schema: oldSchema}}, {multi: true}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Annotation.addMigration new Migration()
