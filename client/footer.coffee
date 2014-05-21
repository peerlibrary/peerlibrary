Template.baseFooter.infiniteScroll = ->
  return true if Session.get variable for variable in _.union ['searchActive'], Catalog.catalogActiveVariables
  false

Template.footer.indexFooter = ->
  'index-footer' if Session.get('indexActive') and not Session.get('searchActive')

Template.footer.noIndexFooter = ->
  'no-index-footer' if not Template.footer.indexFooter()
