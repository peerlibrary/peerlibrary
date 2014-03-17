class Migration extends Document.MinorMigration
  name: "Adding user.username to Annotation's author"

Annotation.addMigration new Migration()
