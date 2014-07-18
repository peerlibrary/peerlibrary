class Migration extends Document.MinorMigration
  name: "Adding searchResults field"

  # Client-only

Annotation.addMigration new Migration()
Collection.addMigration new Migration()
Highlight.addMigration new Migration()
