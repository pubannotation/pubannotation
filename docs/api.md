---
layout: docs
title: API
prev_section: intro
next_section: spans
permalink: /docs/api/
---

All the resources on PubAnnotation can be accessed through its REST API,
which is now the most standard way of accessing resources on the Web.

Note that most of modern programming languages support the REST access and
also there are many standalone REST clients.

For example, [cURL](https://curl.haxx.se/) is a versatile command-line tool you can use as a REST client in major OS environments, e.g., UNIX, iOS, Windows.

To give it a simple try, you can give one of the RESTful URLs as an argument of the cURL command as follows:
<textarea class="command" readonly="readonly">
curl https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.json
</textarea>
Then, it will "get" you the resource represented by the URL: the document, PubMed:25314077, in this case.

PubAnnotation maintains three types of resources

* a *document* is a piece of text which is a sequence of characters.
* *annotations* are statements attached to documents.
   * See [Format]({{site.baseurl}}/docs/annotation-format/) for more details of annotation.
* a *project* is a collection of documents and annotations attached to them.

## Accessing documents

Following examples show various ways of accessing documents in PubAnnotation.
We hope you may figure out the composing rules of URIs while browsing the examples.

### Document list
<!-- * All the documents in PubAnnotation
  * [https://pubannotation.org/docs](https://pubannotation.org/docs)
* All the documents from the same source DB, *PMC*
  * [https://pubannotation.org/docs/sourcedb/PMC](https://pubannotation.org/docs/sourcedb/PMC)
  * the name of source DB is case-sensitive
 -->
* All the documents in a specific project
  * [https://pubannotation.org/projects/example/docs](https://pubannotation.org/projects/example/docs)

### A specific document
* The document whose source DB is *PubMed* and source ID is *25314077*
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077)
* When a document is long, e.g., a full paper, it is divided into multiple divisions.
  * [https://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs](https://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs)
* In the case, for example, the *1*'st div can be accessed in the following way
  * [https://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs/0](https://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs/0)
  * Note that the div specification is based on *0*-oriented indexing.

### A specific span
* A specific span of a document (specified with its beginning and ending caret offsets):
  * [https://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86](https://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86)

### Various formats
* A document can be accessed in HTML, JSON or plain text:
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077)
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.json](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.json)
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.txt](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.txt)
  * In general, it is supposed that the HTML rendering is for human reading, and the JSON and the text formats are for program access.

### Various encoding
* By default, documents are maintained and can be accessed in UTF8 encoding:
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077)

* Document also can be accessed in ASCII encoding, by giving the option, *encoding=ascii*:
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077?encoding=ascii](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077?encoding=ascii)

## Accessing annotations
* All the annotations made to a document can be accessed
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations) (HTML rendering)
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations.json](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations.json) (in JSON)
* Annotations produced by a specific project can be accessed:
  * [https://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/annotations](https://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/annotations)

<!-- * Annotations produced by more than one projects also can be accessed in this way:
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations?projects=[example]](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations?projects=[example])
 -->

* Annotations to a specific span also can be accessed:
  * [https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations](https://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations)

