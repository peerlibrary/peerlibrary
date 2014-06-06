class Migration extends Document.MinorMigration
  name: "Generalizing count fields"

  # Client-only

SearchResult.addMigration new Migration()
