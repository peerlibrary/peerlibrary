class Migration extends Document.UpdateAllMinorMigration
  name: "Adding user.username to author"

Annotation.addMigration new Migration()
Highlight.addMigration new Migration()
