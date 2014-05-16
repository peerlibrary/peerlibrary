importScripts('digest.js/digest.js');
currentChunk = 0;
chunkBuffer = new Array();
hash = Digest.SHA256(),

onmessage = function (oEvent){
  var message = oEvent.data.message;
  ActionHandler[message](oEvent.data);
}

// handles messages received from main thread
var ActionHandler = {
  chunk: function SHA256WebWorkerActionHandler_updateChunk (eventData) {
    // buffering chunk
    chunkBuffer[ eventData.chunkNumber ] = eventData.chunk;
    // flushing buffer
    flushBuffer();
    MessageHandler.progress(eventData.chunkNumber, eventData.chunk.length, 100);
  },
  finalize: function SHA256WebWorkerActionHandler_finalizeChunks (eventData) {
    // flushing buffer before finalizing
    flushBuffer();
    // finalizing
    MessageHandler.done(SHA256WebWorker_getFinalHashString(hash));
  },
  file: function SHA256WebWorkerActionHandler_processFile (eventData) {
    var file = eventData.file;
    var chunkSize = eventData.chunkSize;
    SHA256WebWorker_getSHA256FromFile(file, chunkSize);
  }
}

// structures and sends messages to main thread
var MessageHandler = {
  progress: function SHA256WebWorkerMessageHandler_sendChunkInfo (chunkNumber, chunkSize, fileSize){
    postMessage({
      message: 'chunkDone',
      /*data: {
        //chunkNumber: chunkNumber,
        chunkNumber: -1
        progress: Math.min(chunkSize * (chunkNumber + 1), fileSize) / fileSize
      }*/
    });
  },
  done: function SHA256WebWorkerMessageHandler_sendSHA256 (sha256){
    postMessage({
      message: 'done',
      data: {
        sha256: sha256
      }
    });
  }
}

// converts binary hash to hex (string) representation
function SHA256WebWorker_getFinalHashString (hash) {
  var hexTab = '0123456789abcdef', sha256 = '', _i, _len, a;
  var array = new Uint8Array(hash.finalize());
  for (_i = 0, _len = array.length; _i < _len; _i++) {
    a = array[_i];
    sha256 += hexTab.charAt((a >>> 4) & 0xF) + hexTab.charAt(a & 0xF);
  }
  return sha256;
}

// calculates hash from File/Blob object but in chunks to reduce memory footprint
// this function is obsolete
function SHA256WebWorker_getSHA256FromFile (file, chunkSize){
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

// flushes leading continuos chunks from buffer
function flushBuffer () {
  while( currentChunk in chunkBuffer ) {
    var chunk = chunkBuffer[currentChunk]
    hash.update(chunk);
    delete chunkBuffer[ currentChunk ];
    currentChunk++;
  }
}
