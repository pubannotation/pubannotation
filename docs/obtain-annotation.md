---
layout: docs
title: Obtaining Annotations
prev_section: create-annotation
next_section: format
permalink: /docs/obtain-annotation/
---

For a document in PubAnnotation, you can obtain annotations from a REST service of automatic annotation.

To obtain annotations, PubAnnotation can talk with a web service which

* takes a piece of text through the parameter _text_, and
* responses with annotations in the [PubAnnotation JSON format]({{site.baseurl}}/docs/format/).

To obtain automatic annotations for a document

1. Go to a document page, or a div page in case of PMC document, of your project.<br/>
If the document belongs to one of your projects and if you are logged in, you may find the interface for specifying a REST service of automatic annotation.
![open the editor]({{site.baseurl}}/img/obtain_annotation.png)
2. Put the URL of a web service, then PubAnnotation will "post" the text of the document to the web service, receive the response, and store it in your project, if the response is verified as valid annotation.

## Example of annotation web service

[PubDictionaries](http://pubdictionaries.org) is an example of annotation web service which conforms the specification of PubAnnotation. Through its [_REST API_ interface](http://pubdictionaries.org/mapping/text_annotation),
the URL of a dictionary-based text annotation service can be obtained. The URL can be copied into the input box described above.
