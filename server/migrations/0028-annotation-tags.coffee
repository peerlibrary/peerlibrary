class Migration extends Document.AddRequiredFieldsMigration
  name: "Adding tags field"
  fields:
    tags: []

Annotation.addMigration new Migration()
