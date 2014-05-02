importScripts('digest.js/digest.js');

onmessage = function(oEvent){
  var message = oEvent.data.message;
  ChunkHandler[ message ](oEvent.data);
}

function SHA256WebWorker_getFinalHashString(hash) {
  var hexTab = '0123456789abcdef', sha256 = '', _i, _len, a;
  var array = new Uint8Array(hash.finalize());
  for (_i = 0, _len = array.length; _i < _len; _i++) {
    a = array[_i];
    sha256 += hexTab.charAt((a >>> 4) & 0xF) + hexTab.charAt(a & 0xF);
  }
  return sha256;
}

var ChunkHandler = {
  hash: Digest.SHA256(),
  chunk: function SHA256WebWorkerChunkHandler_updateChunk(eventData) {
    // TODO: Handle chunkNumber
    var chunk = eventData.chunk;
    this.hash.update(chunk);
  },
  finalize: function SHA256WebWorkerChunkHandler_finalizeChunk(eventData) {
    MessageHandler.done(SHA256WebWorker_getFinalHashString(this.hash));
  },
  file: function SHA256WebWorkerChunkHandler_processFile(eventData) {
    var file = eventData.file;
    var chunkSize = eventData.chunkSize;
    SHA256WebWorker_getSHA256FromFile(file, chunkSize);
  }
}

var MessageHandler = {
  progress: function SHA256WebWorkerMessageHandler_sendChunkInfo(chunkNumber, chunkSize, fileSize){
    postMessage({
      message: 'progress',
      data: {
        chunkNumber: chunkNumber,
        progress: Math.min(chunkSize * (chunkNumber + 1), fileSize) / fileSize
      }
    });
  },
  done: function SHA256WebWorkerMessageHandler_sendSHA256(sha256){
    postMessage({
      message: 'done',
      data: {
        sha256: sha256
      }
    });
  }
}

function SHA256WebWorker_getSHA256FromFile(file, chunkSize){
  var fileSize = file.size;
  var reader = new FileReaderSync();
  var hash = Digest.SHA256();
  var chunk;
  for(var i = 0; i < fileSize; i += chunkSize){
    var blob = file.slice(i, chunkSize + i);
    chunk = reader.readAsArrayBuffer(blob);
    hash.update(chunk);
    MessageHandler.progress(i/chunkSize, chunkSize, fileSize);
  }
  MessageHandler.done(SHA256WebWorker_getFinalHashString(hash));
}
