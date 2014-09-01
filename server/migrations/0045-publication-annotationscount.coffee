class Migration extends Document.AddGeneratedFieldsMigration
  name: "Adding annotationsCount field"
  fields: ['annotationsCount']

Publication.addMigration new Migration()
