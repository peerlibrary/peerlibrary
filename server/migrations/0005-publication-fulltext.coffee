class Migration extends Document.AddGeneratedFieldsMigration
  name: "Adding fullText field"
  fields: ['fullText']

Publication.addMigration new Migration()
