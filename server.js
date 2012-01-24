/*
 * Copyright 2012 Joyent, Inc.  All rights reserved.
 *
 * Main entry-point for the Boilerplate API.
 */

var filed = require('filed');
var restify = require('restify');
var uuid = require('node-uuid');



var server = restify.createServer({
  name: 'Boilerplate API'
});
server.log4js.setGlobalLogLevel('TRACE');


// '/eggs/...' endpoints.
var eggs = {}; // My lame in-memory database.
server.get({path: '/eggs', name: 'ListEggs'}, function(req, res, next) {
  var eggsArray = [];
  Object.keys(eggs).forEach(function (u) { eggsArray.push(eggs[u]); });
  res.send(eggsArray);
  return next();
});
server.post({path: '/eggs', name: 'CreateEgg'}, function(req, res, next) {
  var newUuid = uuid();
  var newEgg = {'uuid': newUuid};
  eggs[newUuid] = newEgg;
  res.send(newEgg);
  return next();
});
server.get({path: '/eggs/:uuid', name: 'GetEgg'}, function(req, res, next) {
  var egg = eggs[req.params.uuid];
  if (!egg) {
    return next(new restify.ResourceNotFoundError("No such egg."));
  }
  res.send(egg);
  return next();
});


// TODO: static serve the docs, favicon, etc.
//  waiting on https://github.com/mcavage/node-restify/issues/56 for this.
server.get("/favicon.ico", function (req, res, next) {
  filed(__dirname + '/docs/media/img/favicon.ico').pipe(res);
  next();
});


// Pseudo-W3C (not quite) logging.
server.on('after', function (req, res, name) {
  console.log('[%s] %s "%s %s" (%s)', new Date(), res.statusCode,
    req.method, req.url, name);
});

server.listen(8080, function() {
  console.log('%s listening at %s', server.name, server.url);
});

