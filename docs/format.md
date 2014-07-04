---
layout: docs
title: Format
permalink: /docs/format/
---

PubAnnotation uses [JSON](http://json.org/) as its default format to contain annotations.
This document describes how annotations are represented in JSON in PubAnnotation.

PubAnnotation JSON annotation format supports three different types of information. accomodates supports three different types of annotation:

* *denotation*,
* *relation*, and
* *modification*.

## Denotation

A denotation annotation in PubAnnotation connects a span of text to a conceptual object.
