class Migration extends Document.AddReferenceFieldsMigration
  name: "Adding slug and title to publication"

Annotation.addMigration new Migration()
Highlight.addMigration new Migration()
