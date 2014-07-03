Template.settings.person = ->
  Person.documents.findOne
    slug: Session.get 'currentPersonSlug'

Template.settingsUsername.user = ->
  person = Person.documents.findOne
    slug: Session.get 'currentPersonSlug'
  return person.user


