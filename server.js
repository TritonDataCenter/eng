/*
 * Copyright (c) 2012, Joyent, Inc. All rights reserved.
 *
 * Main entry-point for the Boilerplate API.
 */

var filed = require('filed');
var restify = require('restify');
var uuid = require('node-uuid');
var Logger = require('bunyan');


var log = new Logger({
    name: 'boilerplateapi',
    level: 'debug',
    serializers: {
        err: Logger.stdSerializers.err,
        req: Logger.stdSerializers.req,
        res: restify.bunyan.serializers.response
    }
});



var server = restify.createServer({
    name: 'Boilerplate API',
    log: log
});

// TODO: Add usage of the restify auditLog plugin.


// '/eggs/...' endpoints.
var eggs = {}; // My lame in-memory database.
server.get({path: '/eggs', name: 'ListEggs'}, function (req, res, next) {
    req.log.info('ListEggs start');
    var eggsArray = [];
    Object.keys(eggs).forEach(function (u) { eggsArray.push(eggs[u]); });
    res.send(eggsArray);
    return next();
});
server.post({path: '/eggs', name: 'CreateEgg'}, function (req, res, next) {
    var newUuid = uuid();
    var newEgg = {'uuid': newUuid};
    eggs[newUuid] = newEgg;
    res.send(newEgg);
    return next();
});
server.get({path: '/eggs/:uuid', name: 'GetEgg'}, function (req, res, next) {
    var egg = eggs[req.params.uuid];
    if (!egg) {
        return next(new restify.ResourceNotFoundError('No such egg.'));
    }
    res.send(egg);
    return next();
});


// TODO: static serve the docs, favicon, etc.
//  waiting on https://github.com/mcavage/node-restify/issues/56 for this.
server.get('/favicon.ico', function (req, res, next) {
    filed(__dirname + '/docs/media/img/favicon.ico').pipe(res);
    next();
});


server.listen(8080, function () {
    log.info({url: server.url}, '%s listening', server.name);
});
