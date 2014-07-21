class Migration extends Document.AddRequiredFieldsMigration
  name: "Adding inside field"
  fields:
    inside: []

Annotation.addMigration new Migration()
