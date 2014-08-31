class Migration extends Document.AddGeneratedFieldsMigration
  name: "Adding authorName field"
  fields: ['authorName']

Collection.addMigration new Migration()
