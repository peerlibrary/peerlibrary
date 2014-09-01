# Reverse fields are more like auto fields than synced fields
class Migration extends Document.AddGeneratedFieldsMigration
  name: "Adding annotations field"
  fields: ['annotations']

Publication.addMigration new Migration()
