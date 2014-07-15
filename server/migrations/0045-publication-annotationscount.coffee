class Migration extends Document.AddAutoFieldsMigration
  name: "Adding annotationsCount field"
  fields: ['annotationsCount']

Publication.addMigration new Migration()
