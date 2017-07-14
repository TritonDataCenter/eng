/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/*
 * Copyright (c) 2017, Joyent, Inc.
 */

/*
 * Test the sample code.
 */

var lib = require('../lib/index');

var test = require('tape').test;

test('"correct" argument is required', function (t) {
	t.throws(function () {
		lib.answer();
	}, /correct \(bool\) is required/);
	t.end();
});

test('"correct" argument must be boolean', function (t) {
	t.throws(function () {
		lib.answer('true');
	}, /correct \(bool\) is required/);
	t.end();
});

test('corrupted earth', function (t) {
	var res = lib.answer(false);

	t.ok(res instanceof Error, 'must return an error');
	t.equal(res.message, 'wrong answer: invalid number: "SIX TIMES NINE"',
	    'expected error message');
	t.end();
});

test('douglas adams', function (t) {
	var res = lib.answer(true);

	t.equal(res, 42, 'the answer to life the universe and everything');
	t.end();
});
