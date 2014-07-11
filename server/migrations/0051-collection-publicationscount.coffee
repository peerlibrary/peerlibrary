class Migration extends Document.AddAutoFieldsMigration
  name: "Adding publicationsCount field"
  fields: ['publicationsCount']

Collection.addMigration new Migration()
