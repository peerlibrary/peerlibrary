class Migration extends Document.AddReferenceFieldsMigration
  name: "Adding user.username to author"

Annotation.addMigration new Migration()
Highlight.addMigration new Migration()
