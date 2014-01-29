var readCallback = Npm.require('read');

read = Meteor._wrapAsync(function (options, callback) {
  readCallback(options, function (error, result, isDefault) {
    callback(error, {
      'result': result,
      'isDefault': isDefault
    });
  });
});