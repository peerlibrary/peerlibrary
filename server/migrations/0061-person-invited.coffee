class Migration extends Document.MajorMigration
  name: "Converting invited field into an array and allowing an object for a message"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, invited: {$exists: true}, $where: '!Array.isArray(this.invited)'}, {invited: 1}, (document) =>
      assert not _.isArray document.invited

      count += collection.update {_schema: currentSchema, _id: document._id, invited: document.invited, $where: '!Array.isArray(this.invited)'}, {$set: {invited: [document.invited], _schema: newSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

  backward: (document, collection, currentSchema, oldSchema) =>
    count = 0

    collection.findEach {_schema: currentSchema, invited: {$exists: true}, $where: 'Array.isArray(this.invited)'}, {invited: 1}, (document) =>
      assert _.isArray document.invited

      # We are loosing data here, so the first is as good as any
      invited = document.invited[0]
      # Object messages are not supported in earlier versions
      delete invited.message if _.isObject invited.message
      count += collection.update {_schema: currentSchema, _id: document._id, invited: document.invited, $where: 'Array.isArray(this.invited)'}, {$set: {invited: invited, _schema: oldSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Person.addMigration new Migration()
