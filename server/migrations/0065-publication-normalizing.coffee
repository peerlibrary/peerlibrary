class Migration extends Document.MajorMigration
  name: "Handle changes introduced from normalization"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, files: {$exists: false}}, {importing: 1}, (document) =>
      count += collection.update {_schema: currentSchema, _id: document._id, files: {$exists: false}}, {$set: {files: [{fileID: Random.id(), createdAt: document.createdAt, updatedAt: document.createdAt, SHA256: document.sha256, mediaType: document.mediaType, type: 'original'}],  _schema: newSchema}}

      oldPath = document.cachedFilename().split Storage._path.sep
      oldPath.pop()
      oldPath = oldPath.join(Storage._path.sep) + document.mediaType

      Storage.rename oldPath, document.cachedFilename()

    counts = super
    counts.migrated += count
    counts.all += count
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    collection.findEach {_schema: currentSchema, files: {$exists: true}}, {importing: 1}, (document) =>
      oldPath = document.cachedFilename().split '.'
      oldPath.pop()
      oldPath = oldPath.join('.') + Storage._path.sep + document.files[0].filesID + '.' + document.files[0].mediaType

      storage.rename oldPath, document.cachedFilename()

      oldPath.split Storage._path.sep
      oldPath.pop()
      oldPath.join(Storage._path.sep) + Storage._path.sep
      # Deletes directory?
      storage.remove oldPath


    count = collection.update {_schema: currentSchema}, {$unset: {files: ''}, $set: {_schema: oldSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Publication.addMigration new Migration()
