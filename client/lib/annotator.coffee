class @Annotator
  setTextContent: (pageNumber, textContent) =>
    console.log pageNumber, textContent

  textLayer: (pageNumber) =>
    beginLayout: ->
      console.log pageNumber, "beginLayout"

    endLayout: =>
      console.log pageNumber, "endLayout"

    appendText: (geom) =>
      console.log pageNumber, "appendText", geom

  imageLayer: (pageNumber) =>
    beginLayout: =>
      console.log pageNumber, "beginLayout"

    endLayout: =>
      console.log pageNumber, "endLayout"

    appendImage: (geom) =>
      console.log pageNumber, "appendImage", geom
