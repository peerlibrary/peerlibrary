class Migration extends Document.AddOptionalFieldsMigration
  name: "Adding license field"
  fields: ['license']

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0
    count += collection.update {_schema: currentSchema, license: {$exists: false}, source: 'arXiv'}, {$set: {license: 'arXiv', _schema: newSchema}}, {multi: true}
    count += collection.update {_schema: currentSchema, license: {$exists: false}, source: 'FSM'}, {$set: {license: 'https://creativecommons.org/licenses/by-nc-sa/3.0/us/', _schema: newSchema}}, {multi: true}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Publication.addMigration new Migration()
