---
layout: docs
title: Annotation format
prev_section: create-annotation
next_section: import-annotation
permalink: /docs/annotation-format/
---

PubAnnotation uses [JSON](https://json.org/) as its default format to store annotations.
This document describes how annotations are represented in JSON for PubAnnotation.

PubAnnotation JSON annotation format supports three different types of annotation:

* *denotation*,
* *relation*, and
* *attribute*.

## Denotations

A denotation connects a span of text to a conceptual object.
In following example, there are two denotation annotations:
{% highlight json %}
{
   "text": "IRF-4 expression in CML may be induced by IFN-α therapy",
   "denotations": [
      {"id": "T1", "span": {"begin": 0, "end": 5}, "obj": "Protein"},
      {"id": "T2", "span": {"begin": 42, "end": 47}, "obj": "Protein"}
   ]
}
{% endhighlight %}

Following is a visualization of the above annotation, renderred by [TextAE](https://textae.pubannotation.org/):

<img src="/img/ex-denotation.png" width="450px" />

The example states that there are two denotations, *T1* and *T2*.

* The first one (*T1*) connects the *span 0-5*
(the text spanning between the initial (the 0'th) and the 5'th
<a title="A caret position is the position between two consecutive characters (the position where a vertical bar blinks to show where the cursor is in a text editor). The 0'th caret position is the position before the first character.">caret positions</a>) to he concept *Protein*,
* and the second one (*T2*) connects the *span 42-47* to *Protein*.

While PubAnnotation takes the stance of not forcing semantic interpretation of annotation,
during its default RDFization process, the denotation *T1* will be interpreted as follows:

* the text span between the 0'th and the 5'th caret positions
  * `"span":{"begin":0, "end":5}`
* denotes an entity *T1*
  * `"id":"T1"`
* of which the type is *Protein*.
  * `"obj":"Protein"`


## Relations

A relation connects two entities.

{% highlight json %}
{
   "text": "IRF-4 expression in CML may be induced by IFN-α therapy",
   "denotations": [
      {"id": "T1", "span": {"begin": 0, "end": 5}, "obj": "Protein"},
      {"id": "T2", "span": {"begin": 42, "end": 47}, "obj": "Protein"}
   ],
   "relations": [
      {"id": "R1", "subj": "T1", "pred": "interactWith", "obj": "T2"}
   ]
}
{% endhighlight %}

<img src="/img/ex-relation.png" width="450px" />

The example above states that the two entities, *T1* and *T2*, that are introduced by the two denotations,
are related to each other by the predicate, *interactWith*.
Note that the two entities are specified by the two different keys, *subj* and *obj*,
so the relation is directional.
The design is motivated for a better compatibility with [RDF](https://www.w3.org/RDF/).

Note that PubAnnotation does not enforce any specific annotation scheme,
e.g., the labels for *obj* in denotations and those for *pred* in relations,
and it is fully up to the producer of annotation
how to design the scheme of his/her annotation.
For example, while the way of annotation in above example may be familiar to the community which seeks informatin on protein-protein interaction, another community, e.g., BioNLP Shared Task, may be more familiar with a finer-grained annotation.

{% highlight json %}
{
   "text": "IRF-4 expression in CML may be induced by IFN-α therapy",
   "denotations": [
      {"id": "T1", "span": {"begin": 0, "end": 5}, "obj": "Protein"},
      {"id": "T2", "span": {"begin": 42, "end": 47}, "obj": "Protein"},
      {"id": "E1", "span": {"begin": 6, "end": 16}, "obj": "Expression"},
      {"id": "E2", "span": {"begin": 31, "end": 38}, "obj": "Regulation"}
   ],
   "relations": [
      {"id": "R1", "subj": "T1", "pred": "themeOf", "obj": "E1"},
      {"id": "R2", "subj": "E1", "pred": "themeOf", "obj": "E2"},
      {"id": "R3", "subj": "T2", "pred": "causeOf", "obj": "E2"}
   ]
}
{% endhighlight %}

<img src="/img/ex-relation2.png" width="450px" />

FYI, For color coding of the above example, the following TextAE configuration was used:
{% highlight json %}
{
   "entity types":[
      {"id":"Protein","color":"#AAAAFE","default":true},
      {"id":"Regulation","color":"#AAFEAA"},
      {"id":"Gene_expression","color":"#FEAAAA"}
      ],
   "relation types":[
      {"id":"themeOf","color":"#0000FF","default":true},
      {"id":"causeOf","color":"#FF0000"}
   ]
}
{% endhighlight %}


## Attributes

An attribute annotation adds additional information to a denotation.

{% highlight json %}
{
   "text":"IRF-4 expression in CML may be induced by INF-α therapy",
   "denotations":[
      {"id":"T1","span":{"begin":0,"end":5},"obj":"Protein"},
      {"id":"T2","span":{"begin":42,"end":47},"obj":"Protein"}
   ],
   "attributes":[
      {"id":"A1","subj":"T1","pred":"uniprot","obj":"Q15306"},
      {"id":"A2","subj":"T2","pred":"uniprot","obj":"P01562"},
      {"id":"A3","subj":"T2","pred":"uncertain","obj":true}
   ]
}
{% endhighlight %}

<img src="/img/ex-attribute.png" width="450px" />

In the above example, the attribute annotation, *A1* and *A2*, add the uniprot ID information to *T1* and *t2*.
Also, *A3* tells that the denotation, *T2*, is uncertain.

Note again that the choice of the predicate is up to the designer of the annotation.

FYI, for the color coding of the above example, the following TextAE configuration was used:

{% highlight json %}
{
  "attribute types": [
    {
      "pred": "uniprot",
      "value type": "string",
      "values": [
        {
          "pattern": "default",
          "color": "#55FFFF"
        }
      ]
    },
    {
      "pred": "uncertain",
      "value type": "flag",
      "color": "#FF0000"
    }
 }
{% endhighlight %}


## Multi-layer annotations

Multi-layer annotations - annotations which are made by multiple projects to the same text - can be represented as muptiple tracks.

Usually, you will access annotations within a project, e.g.,

* https://pubannotation.org/__projects/GO-BP__/docs/sourcedb/PubMed/sourceid/10704529/spans/0-119/annotations.json

In the case, you will get the annotations without tracks:

{% highlight json %}
{
   "target":"https://pubannotation.org/docs/sourcedb/PubMed/sourceid/10704529",
   "sourcedb":"PubMed",
   "sourceid":"10704529",
   "text":"Ultrastructural localization of sulfated and unsulfated keratan sulfate in normal and macular corneal dystrophy type I.",
   "project":"GO-BP",
   "denotations":[
      {"id":"T1","span":{"begin":16,"end":28},"obj":"https://purl.obolibrary.org/obo/GO_0051179"},
      {"id":"T5","span":{"begin":32,"end":40},"obj":"https://purl.obolibrary.org/obo/GO_0051923"},
      {"id":"T8","span":{"begin":64,"end":71},"obj":"https://purl.obolibrary.org/obo/GO_0051923"}
   ]
}
{% endhighlight %}

However, if you access annotations without indication of a project (or if you specify multiple projects), e.g.,

* https://pubannotation.org/docs/sourcedb/PubMed/sourceid/10704529/spans/0-119/annotations.json

then you will get the annotations in multiple tracks:

{% highlight json %}
{
   "target":"https://pubannotation.org/docs/sourcedb/PubMed/sourceid/10704529",
   "sourcedb":"PubMed",
   "sourceid":"10704529",
   "text":"Ultrastructural localization of sulfated and unsulfated keratan sulfate in normal and macular corneal dystrophy type I.",
   "tracks":[
      {
         "project":"GO-BP",
         "denotations":[
            {"id":"T1","span":{"begin":16,"end":28},"obj":"https://purl.obolibrary.org/obo/GO_0051179"},
            {"id":"T5","span":{"begin":32,"end":40},"obj":"https://purl.obolibrary.org/obo/GO_0051923"},
            {"id":"T8","span":{"begin":64,"end":71},"obj":"https://purl.obolibrary.org/obo/GO_0051923"}
         ]},
      {
         "project":"GlycoBiology-GDGDB",
         "denotations":[
            {"id":"_T1","span":{"begin":86,"end":116},"obj":"https://acgg.asia/db/diseases/gdgdb?con_ui=CON00391"},
            {"id":"_T2","span":{"begin":86,"end":118},"obj":"https://acgg.asia/db/diseases/gdgdb?con_ui=CON00391"}
         ]
      }
   ]
}
{% endhighlight %}

Note that the difference comes whether a project is specified or not in the URL.


## Discontinuous spans

Sometimes, there may be a case of denotation for which you may want to involve multiple discontinuous spans.
For example, what if you want to annotate _left lung_ in the text, _left or right lung_,
with the ontology id, _UBERON:0002168_.
As the two words are not adjacent to each other, it is not straightforward to specify the span of the denotation.

For representation of discontinuous spans as the span of a denotation, PubAnnotation supports two models:
(1) bagging model, and (2) chaining model.

### Bagging model

In the bagging model, it is allowed to specify the span of a denotation by an array of begin and end offsets, e.g.,

{% highlight json %}
{
   "text":"left and right lung",
   "denotations":[
      {"id":"T2","span":[{"begin":0,"end":4},{"begin":15,"end":19}],"obj":"UBERON:0002168"}
   ]
}
{% endhighlight %}

The bagging model may be intuitively easy to understand particularly in the JSON representation.
However, it is a kind syntactic sugar which is beyond the normal representation of PubAnnotation.
Internally, it is converted to the chaining model.

Note that in the bagging model, a span may be specified either by just a single pair of begin and end offsets,
or by an array of pairs.
Therefore, for a software program to read a JSON representation of annotation,
it must perform a dynamic type checking, a.k.a. _duck typing_.


### Chaining model (default)

The chaining model uses normal syntax of PubAnnotation JSON format.
Instead, it uses special vocabularly to represent an involvement of multiple discontinuous spans in a denotation.
For example, the above example in the bagging model will be internally converted to the chaining model as below:

{% highlight json %}
{
   "text":"left and right lung",
   "denotations":[
      {"id":"T1","span":{"begin":0,"end":4},"obj":"_FRAGMENT"},
      {"id":"T2","span":{"begin":15,"end":19},"obj":"UBERON:0002168"}
   ],
   "relations":[
      {"id":"R1","pred":"_lexicallyChainedTo","subj":"T2","obj":"T1"}
   ]
}
{% endhighlight %}

It will be rendered in TextAE as below:

![chaining discontinuous spans example]({{ site.url }}/img/chaining-discontinuous-spans.png)

PubAnnotation uses the chaining model as default.
The JSON representation in the bagging model can be accessed by
setting the parameter _discontinuous_span_ to be the value, _bag_, e.g.,

* https://pubannotation.org/projects/example/docs/sourcedb/@Jin-Dong%20Kim/sourceid/2/annotations.json?__discontinuous_span=bag__
