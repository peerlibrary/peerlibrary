class Migration extends Document.MinorMigration
  name: "Adding highlights, annotations, groups, and collections counts fields"

  # Client-only

Statistics.addMigration new Migration()
