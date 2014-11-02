Template.baseFooter.helpers
  infiniteScroll: ->
    for variable in _.union ['searchActive', 'libraryActive'], catalogActiveVariables()
      return true if Session.get variable

    return false

Template.footer.helpers
  indexFooter: ->
    'index-footer' if Session.get('indexActive') and not Session.get('searchActive')

  noIndexFooter: ->
    'no-index-footer' if not Template.footer.helpers('indexFooter')()
