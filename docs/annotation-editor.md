---
layout: docs
title: Annotation editors
prev_section: automatic-annotator
next_section: submit-annotation
permalink: /docs/annotation-editor/
---

PubAnnotation is a REST service of text annotations.
From its perspective, an annotation editor is a REST client which

* takes annotations in PubAnnotation (using the GET method),
* makes some changes to the annotations,
* and stores back the changed annotations to PubAnnotation (using the POST method).

For example, note that the annotations made to the document, PubMed:123456 by a project _your-project_,
can be access at the URL:
__http://pubannotation.org/projects/_your-project_/docs/sourcedb/PubMed/sourceid/123456/annotations.json__.

An annotation editor to edit the annotations will then

* 'get' the annotations from the URL, and
* 'post' the annotations to the same URL after edition.

To simulate the IO, one can simply use the cURL command:

1. __curl _the-URL-of-annotations_ > annotations.json__
2. edit the file, _annotations.json_, using an editor, e.g. _vi_
3. __curl -H "content-type:application/json" -u "_username_:_password_" -d @annotations.json _the-URL-of-annotations___

An editor to be compatible with PubAnnotation, besides the API,
it also needs to understand the [PubAnnotation JSON format]({{site.baseurl}}/docs/format/).

[TextAE](http://textae.pubannotation.org) is a web-based graphcial annotation editor,
which meets the specification.
