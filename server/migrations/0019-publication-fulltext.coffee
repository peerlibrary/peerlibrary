class Migration extends Document.PatchMigration
  name: "Modifying Publication's fullText field dependencies"

  # Should not really change any database content

Publication.addMigration new Migration()
