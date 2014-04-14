class Migration extends Document.MinorMigration
  name: "Adding hasAbstract field"

  # Client-only

Publication.addMigration new Migration()
