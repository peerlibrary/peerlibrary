var mongodb = require('mongodb');

var waitingFor = 2;

function tryConnect(url) {
  mongodb.MongoClient.connect(url, {
      server: {
        socketOptions: {
          connectTimeoutMS: 5000,
          socketTimeoutMS: 5000
        }
      }
    }, function (error, db) {
    if (error === null) {
      db.command({ping: 1}, function(error, result) {
        if (error === null) {
          if (--waitingFor <= 0) {
            process.exit(0);
          }
          return;
        }
        else {
          console.error("Waiting for database", error);
        }

        setTimeout(function() { tryConnect(url) }, 100);
      });
      return;
    }
    else {
      console.error("Waiting for database", error);
    }

    setTimeout(function() { tryConnect(url) }, 100);
  });
}

tryConnect(process.env.MONGO_URL);
tryConnect(process.env.MONGO_OPLOG_URL);

