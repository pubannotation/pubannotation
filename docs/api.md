---
layout: docs
title: API
prev_section: intro
next_section: create-project
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
* All the documents in PubAnnotation
  * [http://pubannotation.org/docs](http://pubannotation.org/docs)
* All the documents from the same source DB, *PMC*
  * [http://pubannotation.org/docs/sourcedb/PMC](http://pubannotation.org/docs/sourcedb/PMC)
  * the name of source DB is case-sensitive
* All the documents that belong to a project *example*
  * [http://pubannotation.org/projects/example/docs](http://pubannotation.org/projects/example/docs)
  * A document may belong to multiple projects, as more than one project may annotate same documents.
  * Note that even a document belongs to more than one projects, only one copy of the document is maintained in PubAnnotation.

### Specific document in various formats
* The document whose source DB is *PubMed* and source ID is *25314077*
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077)
* When a document is long, e.g., a full paper, it is divided into multiple divisions.
  * [http://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs](http://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs)
* In the case, for example, the *1*'st div can be accessed in the following way
  * [http://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs/0](http://pubannotation.org/projects/example/docs/sourcedb/PMC/sourceid/4197335/divs/0)
  * Note that the div specification is based on *0*-oriented indexing.

### Various formats
* The same document can be accessed in HTML, which is the default
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077)
* In Json
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.json](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.json)
* Or, in plain text
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.txt](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077.txt)
* Generall, it is supposed that the HTML rendering is for human reading, and the JSON and text format is for program access.

### Various encoding
* By default, the document is maintained with Unicode characters perserved as obtained from the source DB
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077)

* By putting the option, *encoding=ascii*, the document can be accessed with all the unicode characters converted to corresponding ASCII sequences.
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077?encoding=ascii](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077?encoding=ascii)

### Spans
* Any specific span of a document also can be accessed
[http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86](http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86)

## Accessing annotations
* All the annotations made to a specific document can be accessed
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations)
  * in HTML, JSON and text.
* Annotations also can be accessed with a specification of the project
  * [http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/annotations](http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/annotations)
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations?projects=[example]](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations?projects=[example])
  * In the latter form, multiple projects can be specified.
* Annotations also can be accessed in a span-wide
  * [http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations)
  * In the case, annotations are shown in a visualization.

