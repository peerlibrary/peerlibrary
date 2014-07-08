class Migration extends Document.AddSyncedFieldsMigration
  name: "Adding user.username to author"

Annotation.addMigration new Migration()
Highlight.addMigration new Migration()
