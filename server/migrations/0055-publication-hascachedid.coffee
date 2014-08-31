class Migration extends Document.MinorMigration
  name: "Adding hasCachedId field"

  # Client-only

Publication.addMigration new Migration()
