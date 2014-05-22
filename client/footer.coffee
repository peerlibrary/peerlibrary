Template.baseFooter.infiniteScroll = ->
  for variable in _.union ['searchActive'], Catalog.catalogActiveVariables
    return true if Session.get variable

Template.footer.indexFooter = ->
  'index-footer' if Session.get('indexActive') and not Session.get('searchActive')

Template.footer.noIndexFooter = ->
  'no-index-footer' if not Template.footer.indexFooter()
