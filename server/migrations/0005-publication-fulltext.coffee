class Migration extends Document.AddAutoFieldsMigration
  name: "Adding fullText field"
  fields: ['fullText']

Publication.addMigration new Migration()
