class Migration extends Document.MinorMigration
  name: "Adding gravatarHash to Annotation's author"

Annotation.addMigration new Migration()
