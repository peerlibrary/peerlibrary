class Migration extends Document.MinorMigration
  name: "Adding hasAbstract field to Publication"

  # Client-only

Publication.addMigration new Migration()
