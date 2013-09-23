Deps.autorun ->

  Template.upload.events =
    'change input': (e) ->
      _.each e.srcElement.files, (file) ->
        Meteor.savePublication file

  Meteor.savePublication = (blob) ->
    reader = new FileReader()

    reader.onload = () ->
      Meteor.call 'savePublication', Meteor.uuid(), new Uint8Array reader.result

    reader.readAsArrayBuffer blob
