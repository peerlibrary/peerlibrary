importScripts('../digest.js/digest.js');
hash = Digest.SHA256(),

onmessage = function (oEvent){
  var message = oEvent.data.message;
  ActionHandler[message](oEvent.data);
}

// handles messages received from main thread
var ActionHandler = {
  test: function SHA256WebWorkerActionHandler_test (data) {
  },
  ping: function SHA256WebWorkerActionHandler_ping (data) {
    MessageHandler.pong(data); // send data back (pong)
  },
  update: function SHA256WebWorkerActionHandler_updateChunk (eventData) {
    hash.update(eventData.chunk);
    MessageHandler.progress();
  },
  finalize: function SHA256WebWorkerActionHandler_finalizeChunks (eventData) {
    var sha256 = SHA256WebWorker_getFinalHashString(hash);
    MessageHandler.done(sha256);
  }
}

// structures and sends messages to main thread
var MessageHandler = {
  progress: function SHA256WebWorkerMessageHandler_sendChunkInfo () {
    postMessage({
      message: 'progress'
    });
  },
  done: function SHA256WebWorkerMessageHandler_sendSHA256 (sha256){
    postMessage({
      message: 'done',
      data: sha256
    })
  },
  pong: function SHA256WebWorkerMessageHandler_pong (data) {
    postMessage({
      message: 'pong',
      data: data
    })
  },
  print: function debugPrint (message) {
    postMessage({
      message: 'print',
      data: message
    });
  }
}

// converts binary hash to hex (string) representation
function SHA256WebWorker_getFinalHashString (hash) {
  var binaryData = hash.finalize();
  var hexTab = '0123456789abcdef', sha256 = '', _i, _len, a;
  var array = new Uint8Array(binaryData);
  for (_i = 0, _len = array.length; _i < _len; _i++) {
    a = array[_i];
    sha256 += hexTab.charAt((a >>> 4) & 0xF) + hexTab.charAt(a & 0xF);
  }
  return sha256;
}
