---
layout: docs
title: Intro
next_section: api
permalink: /docs/intro/
---

PubAnnotation is a repository of text annotations, especially those made to literature of life sciences, e.g., PubMed or PMC articles.
If one has such annotations, they can be registered in PubAnnotation.
When annotations are registered, PubAnnotation aligns them to the canonical text that is taken from PubMed and PMC,
which means all the annotations in PubAnnotation are linked to each other through canonical texts.
It is a new way of publishing or sharing text annotations using recent web technology:
annotations will become accessible and searchable through standard web protocol, e.g., REST API.

Here is one scenario of using PubAnnotation.
Suppose you have a collection of sentences taken from PubMed.
Perhaps, you collected them because you believed they had references to proteins of your interest.
You may have marked up the protein references with UniProt ID.
You may have accomplished an investigation using the protein-annotated sentences.
Suppose now you want to extend your research to consider their environment, e.g., cellular location.
As environment of a protein may or may not be mentioned in the same sentences,
now you want to look at extended texts, e.g., surrounding texts or even the whole abstracts, for your investigation not to be limited within the sentences.
Then, how would you transfer your annotations to extended texts?
With PubAnnotation, it becomes extremely easy.
You can simply register your annotations to PubAnnotation.
PubAnnotation will find the location of your sentences.
If you are lucky enough, you may find other annotations, e.g., of cellular locations, registered by other people.
As your annotations also will become accessible to the public (you can control it), the visibility of your resources also will become much improved.

* *We are working on extending the documentation.*
* *Your comments or question will help us improve the documentation.*
  * contact: admin@pubannotation.org
* *PubAnnotation is an [open source project](https://github.com/pubannotation/pubannotation). Your any contribution is very welcome.*

<!-- ## Motivation

* It would be good if there is a portal place where we can find most of the annotations made to literature.

* It would be even better if those annotations can be accessed in various common formats.

* It would be great if combulsome problems, e.g., slight variation of text, can be systematically dealt with.

## What is PubAnnotation?

* PubAnnotation is a public repository of literature annotation where anyone can create new annotations or submit existing ones.
 -->
