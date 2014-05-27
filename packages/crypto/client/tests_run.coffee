globals = @

# Download file using XMLHttpRequest
# not using jQuery or HTTP package because they don't support arraybuffer response
pdfPath = "#{ testRoot }/#{ pdfFilename }?" + Math.random()
oReq = new XMLHttpRequest
oReq.open "GET", pdfPath, true
oReq.responseType = 'arraybuffer'
oReq.onload = (oEvent) ->
  globals.pdf = oReq.response
  globals.fileLoaded = true
  globals.processQueue()
oReq.send null
