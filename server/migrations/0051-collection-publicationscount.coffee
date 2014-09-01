class Migration extends Document.AddGeneratedFieldsMigration
  name: "Adding publicationsCount field"
  fields: ['publicationsCount']

Collection.addMigration new Migration()
