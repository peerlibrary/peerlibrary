class Migration extends Document.PatchMigration
  # In the past we stored link between a highlight and an annotation in the
  # document independently from the body. Now we require that each such link
  # has an <a/> tag in the body, so we add dummy links here if such is missing.
  name: "Adding missing reference links to body field"

  forward: (document, collection, currentSchema, newSchema) =>
    count = 0

    # At this stage only highlight references should exist, others were not yet possible through the interface
    collection.findEach {_schema: currentSchema, body: {$exists: true}}, {body: 1, 'references.highlights': 1}, (document) =>
      for highlight in document.references?.highlights or []
        assert highlight._id

        # We do not want to depend on our parsing code as it might change through time and
        # we want migrations to always work. So let's do a simple check here, checking if
        # highlight's ID appears in the body as a string, assuming that is a link.
        continue if new RegExp(highlight._id).test document.body

        newBody = "#{ document.body }<p>(See <a href=\"/h/#{ highlight._id }\">h:#{ highlight._id }</a>)</p>"

        count += collection.update {_schema: currentSchema, _id: document._id, body: document.body}, {$set: {body: newBody, _schema: newSchema}}

    counts = super
    counts.migrated += count
    counts.all += count
    counts

Annotation.addMigration new Migration()
