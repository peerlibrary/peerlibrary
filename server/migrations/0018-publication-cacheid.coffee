getOldFilename = (document) ->
  if document.source is 'arXiv'
    'pdf' + Storage._path.sep + 'arxiv' + Storage._path.sep + document.foreignId + '.pdf'
  else
    # We use import also as a fallback for any unsupported document source.
    # This allows us to go first backward in migrations and then again forward.
    'pdf' + Storage._path.sep + 'import' + Storage._path.sep + document._id + '.pdf'

getNewFilename = (cachedId) ->
  'pdf' + Storage._path.sep + 'cache' + Storage._path.sep + cachedId + '.pdf'

class Migration extends Document.MajorMigration
  name: "Adding cachedId field"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, cachedId: {$exists: false}}, {cached: 1, source: 1, foreignId: 1}, (document) =>
      oldFilename = getOldFilename document

      cachedId = Random.id()
      newFilename = getNewFilename cachedId

      count += collection.update  {_schema: currentSchema, _id: document._id, cachedId: {$exists: false}}, {$set: {cachedId: cachedId, _schema: newSchema}}

      if document.cached
        if document.source is 'arXiv'
          Storage.link oldFilename, newFilename
        else
          Storage.rename oldFilename, newFilename

    counts = super
    counts.migrated += count
    counts.all += count
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, cachedId: $exists: true}, {cached: 1, cachedId: 1, source: 1, foreignId: 1}, (document) =>
      oldFilename = getOldFilename document
      newFilename = getNewFilename document.cachedId

      count += collection.update {_schema: currentSchema, _id: document._id, cachedId: document.cachedId}, {$unset: {cachedId: ''}, $set: {_schema: oldSchema}}

      if document.cached
        if document.source is 'arXiv'
          Storage.remove newFilename
        else
          Storage.rename newFilename, oldFilename

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Publication.addMigration new Migration()
