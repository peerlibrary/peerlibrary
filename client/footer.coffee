Template.baseFooter.searchActive = ->
  Session.get 'searchActive'

Template.footer.indexFooter = ->
  'index-footer' if Session.get('indexActive') and not Session.get('searchActive')

Template.footer.noIndexFooter = ->
  'no-index-footer' if not Template.footer.indexFooter()

Session.setDefault 'backgroundPaused', false

Template.backgroundPauseButton.events
  'click': (e, template) ->
    Session.set('backgroundPaused', not Session.get 'backgroundPaused')
    return # Make sure CoffeeScript does not return anything

Template.backgroundPauseButton.backgroundPaused = ->
  Session.get 'backgroundPaused'
