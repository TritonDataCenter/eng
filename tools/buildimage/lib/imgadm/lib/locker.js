/*
 * Copyright (c) 2014, Joyent, Inc. All rights reserved.
 */
// vim: set sts=4 sw=4 et:

// Ensure we're using the platform's node
// require('/usr/node/node_modules/platform_node_version').assert();

var mod_path = require('path');
var mod_fs = require('fs');
var mod_assert = require('assert');

var mod_lockfd = require('lockfd');

// If we fail to lock (i.e. the call to fcntl() in node-lockfd), and
// the errno is in this list, then we should back off for some delay
// and retry.  Note that an EDEADLK, in particular, is not necessarilly
// a permanent failure in a program using multiple lock files through
// multiple threads of control.
var RETRY_CODES = [
    'EAGAIN',
    'ENOLCK',
    'EDEADLK'
];
var RETRY_DELAY = 250; // ms

var LOCKFILE_MODE = 0644;

var LOCKFILES = [];
var NEXT_HOLDER_ID = 1;

function lockfile_create(path) {
    path = mod_path.normalize(path);

    mod_assert.strictEqual(lockfile_lookup(path), null);

    var lf = {
        lf_path: path,
        lf_state: 'UNLOCKED',
        lf_cbq: [],
        lf_fd: -1,
        lf_holder_id: -1
    };

    LOCKFILES.push(lf);

    return (lf);
}

function lockfile_lookup(path) {
    path = mod_path.normalize(path);

    for (var i = 0; i < LOCKFILES.length; i++) {
        var lf = LOCKFILES[i];

        if (lf.lf_path === path)
            return (lf);
    }

    return (null);
}

// Make an unlock callback for this lockfile to hand to the waiter for whom
// we acquired the lock:
function lockfile_make_unlock(lf) {
    var holder_id;

    mod_assert.strictEqual(lf.lf_holder_id, -1);

    lf.lf_holder_id = holder_id = ++NEXT_HOLDER_ID;

    return (function __unlock(ulcb) {
        mod_assert.strictEqual(lf.lf_holder_id, holder_id,
            'mismatched lock holder or already unlocked');
        lf.lf_holder_id = -1;

        mod_assert.strictEqual(lf.lf_state, 'LOCKED');
        mod_assert.notStrictEqual(lf.lf_fd, -1);

        lf.lf_state = 'UNLOCKING';

        mod_fs.close(lf.lf_fd, function (err) {
            lf.lf_state = 'UNLOCKED';
            lf.lf_fd = -1;

            ulcb(err);

            lockfile_dispatch(lf);
        });
    });
}

function lockfile_dispatch(lf) {
    if (lf.lf_state !== 'UNLOCKED')
        return;

    if (lf.lf_cbq.length === 0) {
        // No more waiters to service for now.
        return;
    }

    lockfile_to_locking(lf);
}

function lockfile_to_locking(lf) {
    mod_assert.strictEqual(lf.lf_state, 'UNLOCKED');
    mod_assert.strictEqual(lf.lf_fd, -1);

    lf.lf_state = 'LOCKING';

    // Open the lock file, creating it if it does not exist:
    mod_fs.open(lf.lf_path, 'w+', LOCKFILE_MODE, function __opencb(err, fd) {
        mod_assert.strictEqual(lf.lf_state, 'LOCKING');
        mod_assert.strictEqual(lf.lf_fd, -1);

        if (err) {
            lf.lf_state = 'UNLOCKED';

            // Dispatch error to the first waiter
            lf.lf_cbq.shift()(err);
            lockfile_dispatch(lf);
            return;
        }

        lf.lf_fd = fd;

        // Attempt to get an exclusive lock on the file via our file
        // descriptor:
        mod_lockfd.lockfd(lf.lf_fd, function __lockfdcb(_err) {
            mod_assert.strictEqual(lf.lf_state, 'LOCKING');

            if (_err) {
                var do_retry = (RETRY_CODES.indexOf(_err.code) !== -1);

                // We could not lock the file, so we should close our fd now:
                mod_fs.close(lf.lf_fd, function __closecb(__err) {
                    // It would be most unfortunate to fail here:
                    mod_assert.ifError(__err);

                    lf.lf_fd = -1;
                    lf.lf_state = 'UNLOCKED';

                    if (do_retry) {
                        // Back off and try again.
                        setTimeout(function __tocb() {
                            lockfile_dispatch(lf);
                        }, RETRY_DELAY);
                        return;
                    }

                    // Report the condition to the first waiter:
                    lf.lf_cbq.shift()(_err);

                    lockfile_dispatch(lf);
                });
                return;
            }

            lf.lf_state = 'LOCKED';

            // Dispatch locking success to first waiter, with unlock callback:
            lf.lf_cbq.shift()(null, lockfile_make_unlock(lf));
        });
    });
}

exports.lock = function (path, callback) {
    var lf = lockfile_lookup(path);
    if (!lf) {
        lf = lockfile_create(path);
    }

    lf.lf_cbq.push(callback);

    lockfile_dispatch(lf);

};
