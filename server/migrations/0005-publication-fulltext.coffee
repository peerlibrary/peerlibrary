class Migration extends Document.UpdateAllMinorMigration
  name: "Adding fullText field"

Publication.addMigration new Migration()
