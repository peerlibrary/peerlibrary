class Migration extends Document.MajorMigration
  name: "Converting highlights field to references field"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, highlights: {$exists: true}, references: {$exists: false}}, {highlights: 1}, (document) =>
      count += collection.update {_schema: currentSchema, _id: document._id, highlights: document.highlights, references: {$exists: false}}, {$unset: {highlights: ''}, $set: {references: {highlights: document.highlights, annotations: [], publications: [], persons: [], tags: []}, _schema: newSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, highlights: {$exists: false}, references: $exists: true}, {references: 1}, (document) =>
      count += collection.update {_schema: currentSchema, _id: document._id, references: document.references}, {$unset: {references: ''}, $set: {highlights: (document.references?.highlights or []), _schema: oldSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Annotation.addMigration new Migration()
