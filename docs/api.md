---
layout: docs
title: API
prev_section: intro
next_section: spans
permalink: /docs/api/
---

All the resources on PubAnnotation can be accessed through the REST API,
which is now the most standard way of accessing resources on the Web.

Note that most of modern programming languages support the REST access and
also there are many standalone REST clients.

For example, [cURL](http://curl.haxx.se/) is a versatile command-line tool you can use as a REST client in major OS environments, e.g., UNIX, iOS, DOS.

To test the API examples shown below, you can simply give one of the RESTful URLs as an argument of the cURL command as follows:
`curl http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.json`

PubAnnotation maintains three types of resources

* a *document* is a piece of text which is a sequence of characters.
* *annotation* is a set of statements attached to a document.
   * See [Format]({{site.baseurl}}/docs/format/) for more details of annotation.
* a *project* is a collection of documents and annotation made to them.

## Accessing documents

Following examples show various ways of accessing documents in PubAnnotation.
We hope you may figure out the composing rules of URIs while browsing the examples.

### Document list
<!-- * All the documents in PubAnnotation
  * [http://pubannotation.org/docs](http://pubannotation.org/docs)
* All the documents from the same source DB, *PMC*
  * [http://pubannotation.org/docs/sourcedb/PMC](http://pubannotation.org/docs/sourcedb/PMC)
  * the name of source DB is case-sensitive
 -->
* All the documents in the project, *example*:
  * [http://pubannotation.org/projects/example/docs](http://pubannotation.org/projects/example/docs)

### A specific document
* The document whose source DB is *PubMed* and source ID is *25314077*
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077)
* When a document is long, e.g., a full paper, it is divided into multiple divisions.
  * [http://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs](http://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs)
* In the case, for example, the *1*'st div can be accessed in the following way
  * [http://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs/0](http://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs/0)
  * Note that the div specification is based on *0*-oriented indexing.

### A specific span
* A specific span of a document (specified with its beginning and ending caret offsets):
  * [http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86](http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86)

### Various formats
* A document can be accessed in HTML, JSON or plain text:
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077)
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.json](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.json)
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.txt](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.txt)
  * In general, it is supposed that the HTML rendering is for human reading, and the JSON and the text formats are for program access.

### Various encoding
* By default, documents are maintained and can be accessed in UTF8 encoding:
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077)

* Document also can be accessed in ASCII encoding, by giving the option, *encoding=ascii*:
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077?encoding=ascii](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077?encoding=ascii)

## Accessing annotations
* All the annotations made to a document can be accessed
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations) (HTML rendering)
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations.json](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations.json) (in JSON)
* Annotations produced by a specific project can be accessed:
  * [http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/annotations](http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/annotations)

<!-- * Annotations produced by more than one projects also can be accessed in this way:
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations?projects=[example]](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations?projects=[example])
 -->

* Annotations to a specific span also can be accessed:
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations)

