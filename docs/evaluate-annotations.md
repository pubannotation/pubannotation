---
layout: docs
title: Evaluate annotations
prev_section: find-location
next_section: shared-task-organize
permalink: /docs/evaluate-annotations/
---

You can compare your project to any other project.
For example, you can use this function to evaluate automatically produced annotations, e.g. your project, to manual annotations.

## Using Browser GUI

1. Go to your project page.
   * top > projects > your_project
2. If you are logged in, you will find the _Evaluations_ button in the pane, _Annotations_.<br/>Click the button to open the _Evaluations_ page of your project.
3. In the _Evaluations_ page, click the _create_ button to create a new evaluation.
4. In the _New evaluation_ form,
   1. Choose the reference project, against which you want to compare project.
   1. Choose an evaluator (currently, only one, _PubAnnotationGeneric_, is available).
5. Click the 'Create evaluation' button, to complete creating an evaluation.
6. Open the evaluation page by clicking the correspondong _show_ button.
   * You will find that evaluation result is not yet available.
7. Click the 'Generate' button to generate the evaluation result.
8. Wait for a few minues, and reload the page to find the result.

## Comparison Metric

Currently, only one annotator, _PubAnnotationGeneric_ is available.
Please refer to the descriptions on the [github page of the source code](https://github.com/pubannotation/pubannotation_evaluator/).

## Example

[bionlp-st-ge-2016-reference-eval](http://pubannotation.org/projects/bionlp-st-ge-2016-reference-eval) is a project cretaed to show the evaluation function of PubAnnotation.

Now, the homepage of a project shows the menu item, _Evaluations_.
Clicking it opens a page with a list of evaluations.

In the project, [bionlp-st-ge-2016-reference-eval](http://pubannotation.org/projects/bionlp-st-ge-2016-reference-eval), three evaluations are created as examples
![list of evaluations]({{site.baseurl}}/img/evaluation-ex-list.png)

All the three evlauations use the same evaluation tool, _PubAnnotationGeneric_, but with different settings.
Below shows the property setting of the first evaluation, which is configured to use a custom matching algorithm when comparing types of denotations:<br>
![properties of an evaluation]({{site.baseurl}}/img/evaluation-ex-properties.png)

For details of the settings, please refer to the [github page](https://github.com/pubannotation/pubannotation_evaluator/).

The evaluation result will be shown in precision / recall / f-score as below:<br>
![result of an evaluation]({{site.baseurl}}/img/evaluation-ex-result.png)

The false positives and false negatives also can be accessed as below:<br>
![false negatives]({{site.baseurl}}/img/evaluation-ex-falses.png)
