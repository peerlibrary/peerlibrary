Template.baseFooter.infiniteScroll = ->
  for variable in _.union ['searchActive', 'libraryActive', 'adminActive', 'adminDevelopment', 'adminPublications', 'adminDatabase', 'adminErrors', 'adminJobs', 'adminSources', 'adminBlog' , 'adminFacts'], catalogActiveVariables
    return true if Session.get variable

  return false

Template.footer.indexFooter = ->
  'index-footer' if Session.get('indexActive') and not Session.get('searchActive')

Template.footer.noIndexFooter = ->
  'no-index-footer' if not Template.footer.indexFooter()
