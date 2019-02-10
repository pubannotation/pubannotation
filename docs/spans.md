---
layout: docs
title: Spans
prev_section: api
next_section: create-project
permalink: /docs/spans/
---

Any span of any document on PubAnnotation may be accessed through its own URI, e.g.,

[http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86)

We call it a _span URI_.

Note that, in a span URI, the document is specified, e.g. '_/docs/sourcedb/PubMed/sourceid/25314077_', and 
the span is specified, e.g. '_/spans/0-86_'.

The span specification of PubAnnotation is based on [caret (text cursor)](https://en.wikipedia.org/wiki/Cursor_(user_interface)) positions.

![caret positions]({{site.baseurl}}/img/caret-position.png)

In the above example, the string '_protein_' exists between the caret positions 4 and 11,
thus its span specifications will be '_/span/4-11_'.

PubAnnotation provides a GUI to get the URI of any span:

1. Open a document page<br/>
![caret positions]({{site.baseurl}}/img/document-screen.png)

2. Select a span, then the URI of the span will appear below the document.<br/>
![caret positions]({{site.baseurl}}/img/span-select-screen.png)

3. Click the URL to open the document page with the selected span highlighted.

Once a span URI is obtained, annotations to the span can be accessed by adding '_/annotations_' to the URL:

[http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations)

The annotations also can be accessed in JSON:

[http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations.json](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations.json)

or in a visualization ([TextAE](http://textae.pubannotation.org)):

[http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations/visualize](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations/visualize)

Note that, to the same document, annotations may be produced by more than one projects,
and all of them will be shown by accessing the above URLs.

The annotations from a specific project can be accessed by specifying the project in the URL as in:

[http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations](http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations)

for HTML rendering, or

[http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations.json](http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations.json)

for JSON representation.

The latter can be supplied to a project specification as a sample annotation.

![caret positions]({{site.baseurl}}/img/sample-in-project.png)

Also, it can be given to [TextAE](http://textae.pubannotation.org) for visualization, e.g.
[http://textae.pubannotation.org/editor.html?target=http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations.json](http://textae.pubannotation.org/editor.html?target=http://pubannotation.org/projects/example/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations.json)


<!-- 
or as in:

[http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations?project=[example]](http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/spans/0-86/annotations?project=[example])
 -->