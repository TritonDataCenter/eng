/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

/*
 * Copyright (c) 2017, Joyent, Inc.
 */

/*
 * A brief overview of this source file: what is its purpose.
 *
 * This file makes available the answer to the ultimate question -- of life,
 * the universe, and everything.
 */

var mod_assert = require('assert-plus');
var mod_jsprim = require('jsprim');
var mod_verror = require('verror');

var THE_ANSWER = '42';
var THE_WRONG_ANSWER = 'SIX TIMES NINE';

function
answer(correct)
{
	mod_assert.bool(correct, 'correct');

	var out = mod_jsprim.parseInteger(correct ? THE_ANSWER :
	    THE_WRONG_ANSWER);

	if (out instanceof Error) {
		return (new mod_verror.VError(out, 'wrong answer'));
	}

	return (out);
}

module.exports = {
	answer: answer
};
