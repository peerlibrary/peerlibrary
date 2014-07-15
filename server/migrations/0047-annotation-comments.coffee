# Reverse fields are more like auto fields than synced fields
class Migration extends Document.AddAutoFieldsMigration
  name: "Adding comments and commentsCount fields"
  fields: ['comments', 'commentsCount']

Annotation.addMigration new Migration()
