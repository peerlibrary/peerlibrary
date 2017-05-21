class Migration extends Document.MajorMigration
  name: "Handle changes introduced from normalization"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, files: {$exists: false}}, {}, (document) =>
      fileId = Random.id()
      update = [
        fileId: fileId
        createdAt: document.createdAt
        updatedAt: document.createdAt
        SHA256: document.sha256
        mediaType: document.mediaType
        type: "original"
      ]
      count += collection.update update {_schema: currentSchema, _id: focument._id, files: {$exists: false}}, {$set: {files: update, _schema: newSchema}}

      cachedFilename = Publication._filenamePrefix() + 'cache' + Storage._path.sep + document.cachedId + Storage._path.sep + fileId + '.' + document.mediaType
      oldPath = cachedFilename.split Storage._path.sep
      oldPath.pop()
      oldPath = oldPath.join(Storage._path.sep) + document.mediaType

      Storage.rename oldPath, cachedFilename

    counts = super
    counts.migrated += count
    counts.all += count
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    collection.findEach {_schema: currentSchema, files: {$exists: true}}, (document) =>
      cachedFilename = Publication._filenamePrefix() + 'cache' + Storage._path.sep + document.cachedId + '.' + document.mediaType
      oldPath = cachedFilename.split '.'
      oldPath.pop()
      oldPath = oldPath.join('.') + Storage._path.sep + document.files[0].filesID + '.' + document.files[0].mediaType

      storage.rename oldPath, cachedFilename

      oldPath.split Storage._path.sep
      oldPath.pop()
      oldPath.join(Storage._path.sep) + Storage._path.sep
      storage.remove oldPath


    count = collection.update {_schema: currentSchema}, {$unset: {files: ''}, $set: {_schema: oldSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Publication.addMigration new Migration()
