class Migration extends Document.RenameFieldsMigration
  name: "Renaming annotations field to referencingAnnotations"
  fields:
    annotations: 'referencingAnnotations'

Annotation.addMigration new Migration()
Highlight.addMigration new Migration()

class MinorMigration extends Document.AddRequiredFieldsMigration
  name: "Adding referencingAnnotations field"
  fields:
    referencingAnnotations: []

Person.addMigration new MinorMigration()
Publication.addMigration new MinorMigration()
