class Migration extends Document.RemoveFieldsMigration
  name: "Removing access, readPersons, readGroups fields"
  fields:
    access: ACCESS.PUBLIC
    readPersons: []
    readGroups: []

Highlight.addMigration new Migration()
