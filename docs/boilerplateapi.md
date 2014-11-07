---
title: Boilerplate API (BAPI)
apisections: Boiled Eggs
markdown2extras: tables, code-friendly
---
<!--
    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
-->

<!--
    Copyright (c) 2014, Joyent, Inc.
-->

# Boilerplate API (BAPI)

*This shows the API implemented by the example node.js server in this repo.
The main point here is show a good way to document API endpoints. You
can copy this file to "docs/index.md" in your repo as a starting
point. Replace this section with an overview of the whole API.*

An API is often dividable into sections, e.g. one section
per resource (in this example "eggs" are the resource). Use an `h1` to
demark those groups and give a reasonable introductory description of this
resource.

One of restdown's conventions is that API endpoints are marked up with an
`h2` header. Special handling of `h2`s as API endpoints is only done for
"apisections" -- note that "Boiled Eggs" is included as an "apisection" in
the metadata at the top of this file.


# Boiled Eggs

{{Overview of this section of the API.}}

## CreateEgg (POST /eggs)

TODO

## ListEggs (GET /eggs)

TODO

## GetEgg (GET /eggs/:uuid)

TODO



