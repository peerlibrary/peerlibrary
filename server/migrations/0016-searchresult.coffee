class Migration extends Document.MinorMigration
  name: "Generalizing SearchResults' fields"

  # Client-only

SearchResult.addMigration new Migration()
