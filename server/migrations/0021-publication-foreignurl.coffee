class Migration extends Document.AddOptionalFieldsMigration
  name: "Adding foreignUrl field"
  fields: ['foreignUrl']

Publication.addMigration new Migration()
