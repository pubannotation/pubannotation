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

1. Go to a document page (or a division page in case of PMC document) of your project.<br/>
If your are logged in and the document belongs to one of your projects, you will find the interface to request annotations from a web service.
![open the editor]({{site.baseurl}}/img/obtain_annotation.png)
2. Enter the **URL** of an annotation service. If you do not know one, see below.
3. Enter the **prefix** for the annotations from the annotation service.
  * Note that individual annotation services may not know about each other, and there is a chance of id confliction among annotations produced by different services, which may cause an unexpected result. By specifying unique prefixes to different annotation services, id confliction can be avoided.
  * A typical prefix may be a short simple character string. It may be discriptive, e.g., 'gene', or just simple enumerations, e.g. 'L1', 'L2', which does not matter much, as long the prefixes are maintained unique to each other within a project.
  * Giving prefixes properly is particularly important when annotations are obtained in the 'add' mode (See below).
4. Choose the **storing mode**: _replace_ or _add_.
  * In the _replace_ mode, the obtained annotations will replace current annotations. In other words, current annotations will be all deleted before the newly obtained annotations are stored.
  * In the _add_ mode, current annotations will be preserved and the obtained annotations will be additionally stored. 
5. Click the button, **Request annotation**, then PubAnnotation will "post" the text of the document to the web service, receive the response, and store it in your project, if the response is verified as valid annotations.

## Example of annotation web service

[PubDictionaries](http://pubdictionaries.org) is an example of annotation web service which conforms the specification of PubAnnotation. Through its [_REST API_ interface](http://pubdictionaries.org/mapping/text_annotation),
the URL of a dictionary-based text annotation service can be obtained. The URL can then be copied into the input box described above.
