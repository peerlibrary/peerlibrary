globals = @

# Download file using XMLHttpRequest
# not using jQuery or HTTP package because they don't support arraybuffer response
@downloadPdf = (callback) ->
  # if file is already downloaded just send it to callback
  if globals.pdf
    callback null, globals.pdf
    return

  # otherwise download it
  pdfPath = "#{ testRoot }/#{ pdfFilename }?" + Math.random()
  oReq = new XMLHttpRequest
  oReq.open "GET", pdfPath, true
  oReq.responseType = 'arraybuffer'
  oReq.onload = (oEvent) ->
    callback null, oReq.response
  oReq.onerror = () ->
    callback oReq.status, null
  oReq.send null

@downloadComplete = (error, file) ->
  if error
    throw new Error error
  globals.pdf = file


# Generic tests

# This test does not require file to be downloaded
Tinytest.addAsync "Checking package visibility", (test, onComplete) ->
  globals.createHash()
  test.isTrue globals.isDefined, "Crypto.SHA256 is not defined"
  test.isTrue Package['crypto'].Crypto.SHA256, "Package.sha256.Crypto.SHA256 is not defined"
  onComplete()

testAsyncMulti "Checking file size", [
  (test, expect) ->
    globals.downloadPdf expect globals.downloadComplete
,
  (test, expect) ->
    test.equal globals.pdf.byteLength, pdfByteLength, "Invalid downloaded file size"
]
