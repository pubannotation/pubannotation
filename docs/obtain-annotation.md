---
layout: docs
title: Obtaining annotations
prev_section: import-annotation
next_section: annotation-server-api
permalink: /docs/obtain-annotation/
---

For documents in a project, annotations can be obtained from an external web service,
wich we call an annotation server.

Pre-registered annotation servers can be found at the [annotators](http://pubannotation.org/annotators) page of PubAnnotation.

An new annotation server can be registered at the same page.




To obtain annotations, PubAnnotation can talk with a web service which

* takes a piece of text through the parameter, _text_, and
* responses with annotations to the text.
  * for PubAnnotation to understand the response, annotations need to be in the [PubAnnotation JSON format]({{site.baseurl}}/docs/annotation-format/).



The web service may produce annotation 

To obtain automatic annotations for a document,

1. Go to a document page (or a division page in case of PMC document) of your project.<br/>
If your are logged in and the document belongs to one of your projects, you will find the interface to request annotations from a web service.<br/>
![open the editor]({{site.baseurl}}/img/obtain_annotation_form.png)
2. Enter the **URL** of an annotation service. If you do not know one, see below.
3. Optionally, enter the **prefix** for the annotations from the annotation service.
  * Note that individual annotation services may not know about each other, and there is a chance of id confliction among annotations produced by different services, which may cause an unexpected result. By specifying unique prefixes to different annotation services, id confliction can be avoided.
  * A typical prefix may be a short simple character string. It may be discriptive, e.g., 'gene', or just simple enumerations, e.g. 'L1', 'L2', which does not matter much, as long the prefixes are maintained unique to each other within a project.
  * Giving prefixes properly is particularly important when annotations are obtained in the 'add' mode (See below).
4. Choose the **storing mode**: _replace_ or _add_.
  * In the _replace_ mode, the obtained annotations will replace current annotations. In other words, current annotations will be all deleted before the newly obtained annotations are stored.
  * In the _add_ mode, current annotations will be preserved and the obtained annotations will be additionally stored.
5. Click the button, **Request annotation**, then PubAnnotation will "post" the text of the document to the web service, receive the response, and store it in your project, if the response is verified as valid annotations.

To obtain automatic annotations for the all documents in a project,

1. Go to the front page of a project
If your are logged in and project belongs to you, you will find the button, 'Obtain Annotations'.
2. Click the button, 'Obtain Annotations', and you will find a similar interface as above.
3. The usage of the interface is mostly the same as above, except here you can specify which documents you want to annotate.

## PubAnnotation-compatible annotation web services

For an annotation web service to be compatible with PubAnnotation, it has to take either

* a piece of text through the parameter variable, _text_, e.g.
<textarea class="bash" style="width:100%; height:3em; background-color:#333333; color:#eeeeee">
curl -d text="example text" URL_of_annotation_web_service
</textarea>

* or, a combination of source DB and source Id, e.g.
<textarea class="bash" style="width:100%; height:3em; background-color:#333333; color:#eeeeee">
curl -d sourcedb="PubMed" -d sourceid="123456" URL_of_annotation_web_service
</textarea>

The verb of the request may be either POST (the above examples), or GET (put the option "-G" to the above examples).

In either case, the response has to be annotations encoded in the [PubAnnotation JSON format]({{site.baseurl}}/docs/annotation-format/).

## Annotation web service example

[PubDictionaries](http://pubdictionaries.org) is an example of annotation web service which conforms the specification of PubAnnotation. Through its [_REST API_ interface](http://pubdictionaries.org/text_annotation),
the URL of a dictionary-based text annotation service can be obtained. The URL can then be copied into the input box described above.