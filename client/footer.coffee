Template.baseFooter.searchActive = ->
  Session.get 'searchActive'

Template.footer.VERSION = __meteor_runtime_config__.VERSION

Template.footer.indexFooter = ->
  'index-footer' if Session.get('indexActive') and Session.get('indexHeader') and not Session.get('searchActive')
