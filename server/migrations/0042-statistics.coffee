class Migration extends Document.MinorMigration
  name: "Adding highlights, annotations, groups, and collections counts fields to statistics"

  # Client-only

Statistics.addMigration new Migration()
