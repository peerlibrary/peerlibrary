# Replacing is removing (major) + adding (minor), so we choose RemoveReferenceFieldsMigration
class Migration extends Document.RemoveReferenceFieldsMigration
  name: "Replacing givenName and familyName with displayName"

Annotation.addMigration new Migration()
Collection.addMigration new Migration()
Comment.addMigration new Migration()
Group.addMigration new Migration()
Highlight.addMigration new Migration()
Person.addMigration new Migration()
Publication.addMigration new Migration()
