class Migration extends Document.AddRequiredFieldsMigration
  name: "Adding groups, collections, comments, and urls to references field"
  fields:
    'references.groups': []
    'references.collections': []
    'references.comments': []
    'references.urls': []

Annotation.addMigration new Migration()
