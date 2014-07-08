class Migration extends Document.AddRequiredFieldsMigration
  name: "Adding access, readPersons, readGroups fields"
  fields:
    access: Publication.ACCESS.OPEN
    readPersons: []
    readGroups: []

Publication.addMigration new Migration()
