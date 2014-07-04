---
layout: docs
title: Format
permalink: /docs/format/
---

PubAnnotation uses [JSON](http://json.org/) as its default format to contain annotations.
This document describes how annotations are represented in JSON in PubAnnotation.

PubAnnotation JSON annotation format supports three different types of information. accomodates supports three different types of annotation:

* *denotation*,
* *relation*, and
* *modification*.

## Denotation

A denotation annotation in PubAnnotation connects a span of text to a conceptual object.

{% highlight json %}
{
   "text": "IRF-4 expression in CML may be induced by IFN-α therapy",
   "denotations": [
      {"id": "T1", "span": {"begin": 0, "end": 5}, "obj": "Protein"},
      {"id": "T2", "span": {"begin": 42, "end": 47}, "obj": "Protein"}
   ]
}
{% endhighlight %}

![denotation]({{ site.url }}/img/ex-denotation.png)
