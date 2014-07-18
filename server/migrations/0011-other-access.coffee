class Migration extends Document.AddRequiredFieldsMigration
  name: "Adding access, readPersons, readGroups fields"

  constructor: (defaultAccess) ->
    super
      access: defaultAccess
      readPersons: []
      readGroups: []

Annotation.addMigration new Migration ACCESS.PRIVATE
Highlight.addMigration new Migration ACCESS.PUBLIC
