class Migration extends Document.AddRequiredFieldsMigration
  name: "Adding license field"
  fields:
    license: 'CC0-1.0+'

Annotation.addMigration new Migration()
