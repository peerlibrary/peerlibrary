Template.baseFooter.searchActive = ->
  Session.get 'searchActive'

Template.footer.indexFooter = ->
  'index-footer' if Session.get('indexActive') and not Session.get('searchActive')

Template.footer.noIndexFooter = ->
  'no-index-footer' if not Template.footer.indexFooter()

Session.setDefault 'backgroundPaused', 0

Template.view.events
  'click': (e, template) ->
    Session.set 'backgroundPaused', 1 - Session.get 'backgroundPaused'
    return

Template.view.viewText = ->
  return '   Basic View' unless Session.get 'backgroundPaused'
  'Standard View'