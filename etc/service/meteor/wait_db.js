var mongodb = require('mongodb');

var waitingFor = 2;

function tryConnect(url) {
  mongodb.MongoClient.connect(url, function (error, db) {
    if (error === null) {
      db.command({ping:1}, function(error, result) {
        if (error === null) {
          if (--waitingFor <= 0) {
            process.exit(0);
          }
          return;
        }

        setTimeout(function() { tryConnect(url) }, 100);
      });
      return;
    }

    setTimeout(function() { tryConnect(url) }, 100);
  });
}

tryConnect(process.env.MONGO_URL);
tryConnect(process.env.MONGO_OPLOG_URL);
