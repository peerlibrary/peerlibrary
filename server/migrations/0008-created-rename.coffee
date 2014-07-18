class Migration extends Document.RenameFieldsMigration
  name: "Renaming created and updated fields to createdAt and updatedAt"
  fields:
    created: 'createdAt'
    updated: 'updatedAt'

Annotation.addMigration new Migration()
Highlight.addMigration new Migration()
Person.addMigration new Migration()
Publication.addMigration new Migration()
