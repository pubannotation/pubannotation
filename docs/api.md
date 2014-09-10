---
layout: docs
title: API
prev_section: format
next_section: about
permalink: /docs/api/
---

PubAnnotation provides a REST API for programmable access.
This document describes how resources on PubAnnotation can be accessed through REST API.

PubAnnotation stores three types of resources

* *projects*
* *documents*,
* *texts*, and
* *annotations*.

## Documents

A document in PubAnnotation can be access through

* all documents
  * `http://pubannotation.org/docs/`
* all documents that belong to a project *ex_project*
  * `http://pubannotation.org/projects/ex_project/docs/`
* The document whose source DB is *ex_DB* and source ID is *ex_ID*
  * `http://pubannotation.org/docs/sourcedb/ex_DB/sourceid/ex_ID/`
* When a document is long, e.g., full paper, it is divided in to multiple divisions. In the case, the *n*'th division can be accessed as like
  * `http://pubannotation.org/docs/sourcedb/ex_DB/sourceid/ex_ID/divs/n`


