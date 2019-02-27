---
layout: docs
title: Comparing projects
prev_section: find-location
next_section: shared-task
permalink: /docs/compare-project/
---

<script src='https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js?config=TeX-MML-AM_CHTML' async></script>

You can compare your project to any other project.
For example, you can use this function to evaluate automatically produced annotations, e.g. your project, to manual annotations.

## Using Browser GUI

1. Go to your project page.
   * top > projects > your_project
2. If you are logged in, you will find the _compare_ menu in the pane, _Annotations_<br>
![compare_projects_annotations]({{site.baseurl}}/img/compare_projects.png)
3. Enter the name of an existing project, and click the button.
4. After a while for computation, a link to comparison page will be shown in the _compare_ menu.

## Comparison Metric

In PubAnnotation, when a project is compared against another project,
we call the former a _study project_ and the latter a _reference project_.
When the two projects include different sets of documents,
only the documents shared by the two are considered, and the others are ignored.

For the set of shared documents,
the set of annotations in the study project (called _study annotations_), $$A_S$$,
are compared against the set of annoations in the reference project (_reference annotations_), $$A_R$$.

The number of true positives (TP), false positives (FP), and false negatives (FN) are counted as below:

$$TP = | A_S \cap A_R |$$

$$FP = | A_S - A_R |$$

$$FN = | A_R - A_S |$$

The precision (P), recall (R), and F-score (F) are then calculated as below:

$$P = \frac{TP}{TP + FP}$$

$$R = \frac{TP}{TP + FN}$$

$$F = \frac{2PR}{P + R}$$


### Comparision of denotations

Denotations and relations are evaluated separetely.

For the set of shared documents between two projects,
the set of study denotations, $$D_S$$, is compared against the set of reference denotations, $$D_R$$.

As explained in [Format]({{site.baseurl}}/docs/annotation-format/), a denotation is represented as a triple: < _begin_offset_, _end_offset_, _label_ >.

Note that as a denotation is bound to a specific document, in fact, the character offsets, _begin_offset_ and _end_offset_, should be prefixed with a document Id, e.g., _docid:begin_offset_, which is however omitted here
for the sake of simplicity.

When we consider only exact matching between the study and reference denotations,
comparison is performaed based on equibvalence,
e.g., two denotations, $$d_1$$ and $$d_2$$ are equivalent to each other if and only if the three elements, _begin_offset_, _end_offset_, _label_, are the same between the two denotations.
In the case, there is 1-to-1 correspondence between matching annotations.

![1-to-1 correspondence between matching annotations]({{site.baseurl}}/img/evaluation-1-to-1.png)

In the figure above, $$s_1$$ matches to $$r_1$$, making it a true positive.
$$s_2$$ is a false potive, and $$r_2$$ is a false negative.
In the case, computation of precision and recall is straightforward.

Sometimes, a soft matching scheme is desired over exact matching.
For example, it is a common thought that exact span matching is a too much strict criterion for named entity recognition (NER),
and evaluation of many NER tasks employs a sloppy span matching scheme:
if there is a overlap between two spans, they are considered to match each other.
However, such a soft matching scheme often yeilds a non 1-to-1 correspondence between matching annotations.

![1-to-n correspondence between matching annotations]({{site.baseurl}}/img/evaluation-1-to-n.png)

In (a) of the figure above, the annotation, $$s_1$$, matches to two annotations, $$r_1$$ and $$r_2$$,
e.g., the span of $$s_1$$ includes the spans of both $$r_1$$ and $$r_2$$.
In the case, the calulation of precision is still simple: one shot out of two has missed, so $$P = \frac{1}{2}$$.
Caluation of recall is however tricky:
while all the two reference annotations have found their match,
we do not want to say the recall is 100% because the study annotations have only one matching annotation.
To simplify the calculation of recall, we set a rule:
_one shot can kill only one at most_.
According to the rule, the matching between $$s_1$$ and $$r_2$$ is deleted,
in the notion that $$s_1$$ is already consumed to kill $$r_1$$, and cannot be reused for $$r_2$$.
Then, only 1-to-1 correspondence remains, and calculation of recall becomes simple (see (b) of the figure above).


![n-to-1 correspondence between matching annotations]({{site.baseurl}}/img/evaluation-n-to-1.png)

In (a) of the figure above, two annotations, $$s_1$$ and $$s_2$$, matches to one annotation, $$r_1$$,
e.g., the spans of $$s_1$$ and $$s_2$$ are included in the span of $$r_1$$.
In the case, the calulation of recall is simple: one shot out of two is missed, so $$R = \frac{1}{2}$$.
This time, caluation of precision is tricky:
while all the two study annotations have found their match,
we do not want to say the precision is 100% because only one reference annotation is shot.
To simplify the calculation of precision, we set another rule:
_one shot is sufficient to kill one_.
According to the rule, the matching between $$s_2$$ and $$r_1$$ is deleted,
in the notion that $$r_1$$ is already killed by $$s_1$$,
and $$s_2$$ is a redundant shot.
Then, only 1-to-1 correspondence remains, and calculation of precision becomes simple (see (b) of the figure above).


### Comparison of relations

For the set of shared documents between two projects,
the set of study relations, $$R_S$$, is compared against the set of reference relations, $$R_R$$.

A relation is represented as a triple: < _id_of_subject_denotation_, _predicate_, _id_of_object_denotation_ >.
It means a relation is dependant on two denotations.
In many cases, however, we cannot expect that the Ids of denotations to remain the same across $$R_S$$ and $$R_R$$.
The Ids of denotations in a relation representation are thus replaced with the representations of denotations, e.g.
< _representation_of_subject_denotation_, _predicate_, _representation_of_object_denotation_ >,
then the comparison becomes agnostic to the Ids.
Note that the representation of a denotation is triple,
and the representation of a relation becomes septuple after the id of a denoation is replaced to the representation.

Once id-agnostic representation of relations is acheived, comparison between $$R_S$$ and $$R_R$$ is performed exactly the same way as the comparision of denotations.

A non-1-to-1-correspondence issue is resolved exactly the same way as the comparison of denotations.
