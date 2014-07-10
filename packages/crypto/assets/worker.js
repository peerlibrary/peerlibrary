importScripts('../digest.js/digest.js');

var hash = Digest.SHA256();

addEventListener('message', function (event) {
  var message = event.data.message;
  ActionHandler[message](event.data);
});

// Handles messages received from main thread
var ActionHandler = {
  test: function (eventData) {
  },
  ping: function (eventData) {
    // Sends data back (pong) so we can verify how communication with the worker works
    MessageHandler.pong(eventData);
  },
  update: function (eventData) {
    hash.update(eventData.chunk);
    MessageHandler.chunkDone();
  },
  finalize: function (eventData) {
    var sha256 = finalizeHash(hash);
    MessageHandler.done(sha256);
  }
};

// Sends messages to main thread
var MessageHandler = {
  chunkDone: function () {
    postMessage({
      message: 'chunkDone'
    });
  },
  done: function (sha256) {
    postMessage({
      message: 'done',
      data: sha256
    });
  },
  pong: function (data) {
    postMessage({
      message: 'pong',
      data: data
    });
  }
};

// Converts binary hash to hex (string) representation
function finalizeHash(hash) {
  var binaryData = hash.finalize();
  var hexTab = '0123456789abcdef', sha256 = '', _i, _len, a;
  var array = new Uint8Array(binaryData);
  for (_i = 0, _len = array.length; _i < _len; _i++) {
    a = array[_i];
    sha256 += hexTab.charAt((a >>> 4) & 0xF) + hexTab.charAt(a & 0xF);
  }
  return sha256;
}
