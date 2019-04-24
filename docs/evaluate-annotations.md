---
layout: docs
title: Evaluate annotations
prev_section: find-location
next_section: shared-task-organize
permalink: /docs/evaluate-annotations/
---

<script src='https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/MathJax.js?config=TeX-MML-AM_CHTML' async></script>

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