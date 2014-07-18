class Migration extends Document.AddAutoFieldsMigration
  name: "Adding authorName field"
  fields: ['authorName']

Collection.addMigration new Migration()
