---
layout: docs
title: API
prev_section: format
next_section: add-documents
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
* all documents that belong to a project *x*
  * `http://pubannotation.org/projects/x/docs/`
* The document whose source DB is *PMC* and source ID is *1234*
  * `http://pubannotation.org/docs/sourcedb/PMC/sourceid/1234/`
* When a document is long, e.g., full paper, it is divided in to multiple divisions. In the case, the *n*'th division can be accessed as like
  * `http://pubannotation.org/docs/sourcedb/PMC/sourceid/1234/divs/n`


