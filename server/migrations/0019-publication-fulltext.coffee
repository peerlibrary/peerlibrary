class Migration extends Document.PatchMigration
  name: "Modifying fullText field dependencies"

  # Should not really change any database content

Publication.addMigration new Migration()
