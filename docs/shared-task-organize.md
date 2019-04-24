---
layout: docs
title: Shared task organization
prev_section: evaluate-annotations
next_section: shared-task-participate
permalink: /docs/shared-task-organize/
---

Pubannotation can be used as a platform for shared task organization.

## Shared Task Definition 

In PubAnnotation, it is assumed that a shared task is implemented by
* benchmark data sets, and
* evaluation tools.

Here, _benchmark data_ means _annotation data_, which is assumed to have reliable annotation.

For shared task organization, a benchmark data set is often divided into three mutually exclusive sets:
* reference data set,
* development data set, and
* test data set.

The _reference data set_, a.k.a., _training data set_,
is intended to be referenced for development of automatic annotation systems.

While the term _training set_ is a much more popular term, we have a concern that the term may imply a machine learning approach to be used, and we have chosen to use the term _reference set_, to stay neutral over any possible approaches.

The _development data set_ is used for various purposes.
For machine learning approaches, it is usually used to optimize hyper parameters.
For approaches which do not need hyper parameter setting, it may be merge to the reference set in favor of more reference data.
For shared task organization, sometimes it is used to provide partcipants with a chance of practice for final submissions.

The performance of automatic annotation systems are evaluated against the _test data set_.
To ensure prevention of overfitting (whether intended or unintended),
often only the raw texts of an test data set are made open,
while the annotation to the texts are kept hidden.

## Shared task organization

Using PubAnnotation, a shared task can be operated in following way:

### 1. To release benchmark data sets

Release of the reference, development and test data sets can be done by creating three separate projects ([creating annotations]({{site.baseurl}}/docs/create-annotation/)), e.g., _ST1-reference_, _ST1-development_, and _ST1-test_, and uploading annotation data sets to the projects ([submitting annotations]({{site.baseurl}}/docs/submit-annotation/)).

If you want to hide the annotation and to open only the raw texts of the test data set, you can set the _accessibility_ property of the corresponding project, e.g., _ST1-test_, to be _blind_. The annotation data of the project will then become only visible to the maintainer of the project.

Make it sure to create a downloadable archive file in your projects. Otherwise users cannot download your data sets.

After creating multiple projects for multiple data sets, you may want them to be accessed as a group.
You can create a collection, e.g., _ST1_, to which you can put your projects ([creating collections]({{site.baseurl}}/docs/create-collection/)).
If you specify the collection as a _shared task_, it will be listed in the shared task section in the front page of PubAnnotation.

### 2. To provide supporting data sets

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

You can put all the projects of supporting data sets into the collection of your shared task, so that paritipants can find them easily.

### 3. To see results of participation

TBD