# ArrayBuffer.prototype.slice polyfill
# See https://developer.mozilla.org/en-US/docs/Web/API/ArrayBuffer#slice%28%29
# and http://stackoverflow.com/a/10101213

if not ArrayBuffer.prototype.slice
  ArrayBuffer.prototype.slice = (start, end) ->
    that = new Uint8Array this
    end = that.length if typeof end is 'undefined'
    result = new ArrayBuffer end - start
    resultArray = new Uint8Array result
    for i in [0..resultArray.length]
      resultArray[i] = that[i + start]
    result
