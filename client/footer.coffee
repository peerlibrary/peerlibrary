Template.baseFooter.searchActive = ->
  Session.get 'searchActive'

Template.footer.indexFooter = ->
  'index-footer' if Session.get('indexActive') and Session.get('indexHeader') and not Session.get('searchActive')

Template.footer.noIndexFooter = ->
  'no-index-footer' if not Template.footer.indexFooter()

Template.footer.VERSION = VERSION