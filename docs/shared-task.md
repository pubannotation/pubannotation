---
layout: docs
title: Shared task organization
prev_section: compare-project
next_section: example-align
permalink: /docs/shared-task/
---

Pubannotation can be used as a platform for shared task organization.

## Shared Tasks at PubAnnotation

In PubAnnotation, it is assumed that a shared task is implemented by
* benchmark data sets, and
* evaluation tools.

Here, _benchmark data_ means _annotation data_, which is assumed to have reliable annotation.

For shared task organization, a benchmark data set is often divided into three mutually exclusive sets:
* reference data set,
* development data set, and
* evaluation data set.

The _reference data set_, a.k.a., _training data set_,
is intended to be referenced for development of automatic annotation systems.

While the term _training set_ is a much more popular term, we have a concern that the term may imply a machine learning approach to be used, and we have chosen to use the term _reference set_, to stay neutral over any possible approaches.

The _development data set_ is used for various purposes.
For machine learning approaches, it is usually used to optimize hyper parameters.
For approaches which do not need hyper parameter setting, it may be merge to the reference set in favor of more reference data.
For shared task organization, sometimes it is used to provide partcipants with a chance of practice for final submissions.

The performance of automatic annotation systems are evaluated against the _evaluation data set_.
To ensure prevention of overfitting (whether intended or unintended),
often only the raw texts of an evaluation data set are made open,
while the annotation to the texts are kept hidden.

## Shared task organization at PubAnnotation

Using PubAnnotation, a shared task can be operated in following way:

### 1. Release of benchmark data sets

Reasing benchmark data sets is straightforward with PubAnnotation.

Release of the reference, development and devaluation data sets can be done by creating three separate projects ([creating annotations]({{site.baseurl}}/docs/create-annotation/)), e.g., _ST1-reference_, _ST1-development_, and _ST1-evaluation_, and uploading annotation data sets to the projects ([importing annotations]({{site.baseurl}}/docs/import-annotation/)).

If you want to hide the annotation and to open only the raw texts of the evaluation data set, you can set the _accessibility_ property of the corresponding project, e.g., _ST1-evaluation_, to be _blind_. The annotation data of the project will then become only visible to the maintainer of the project.

### 2. Provision of supporting data

In some shared task organization, e.g., BioNLP-ST 2009, 2011, 2013 and 2016,
participants were provided with _supporting data sets_,
which were precomputed annotations,
e.g., part-of-speech tagging, syntactic parsing, named entity recognition, and so on,
using publicly available tools, to the benchmark data sets.
The idea was that as those tools are publicly available,
by providing precomtuted data using those tools,
participants may save their time to find, install, and running the tools.
and be able to better concentrate on the shared task itself.

By design, PubAnnotation is an ideal platform to provide supporting data sets for shared tasks.

Suppose that a shared task is organized with benchmark data sets which include texts, t1, t2, ..., tn.
Providing a supporting data set, e.g., syntactic parsing result, for the shared task is straightforward:
1. to create a project ([creating annotations]({{site.baseurl}}/docs/create-annotation/)).
1. to import the texts from the projects of the shared task ([importing documents]({{site.baseurl}}/docs/import-document/)).
1. to add annotation, e.g., syntactic parsing, to the texts ([adding annotations]({{site.baseurl}}/docs/add-annotation/)).

If the _accessibility_ property of the project is set to be _public_, then the annotation of the project will become accessible together with the annotation of the benchamark data sets of the shared task.

### 3. Participation

For potential participants to actually participate in the shared task,
they need to be able to
1. obtain the raw text of the benchmark data sets, either the training, development, or evaluation data set.
1. submit their own annotation to texts, and
1. get evaluation of their annotation.

To do it in Pubannotation, a participant will
1. create a project ([creating annotations]({{site.baseurl}}/docs/create-annotation/)),
1. import texts from a project, either training, development or evaluation data set, of the shared task ([importing documents]({{site.baseurl}}/docs/import-document/)),
1. add her (his) own annotation to the texts ([adding annotations]({{site.baseurl}}/docs/add-annotation/)), and
1. compare the project against the corresponding project of the shared task ([comparing projects]({{site.baseurl}}/docs/compare-project/)).
