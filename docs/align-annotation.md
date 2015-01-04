---
layout: docs
title: Align Annotation
prev_section: submit-annotation
next_section: about
permalink: /docs/align-annotation/
---

Even if you do not want to deposit your annotations to PubAnnotation,
you can still get your annotations aligned to others on PubAnnotation.

To do it, you can follow [the instructions for submitting annotations]({{site.baseurl}}/docs/submit-annotation/), but without specifying a project.

Following command shows an example usage of cURL to get your annotation aligned:
<input type="text" class="bash" value='curl -H "content-type:application/json" -d @your_annotation_file.json "http://pubannotation.org/docs/sourcedb/PubMed/sourceid/123456/annotations.json"
'>

For more detail of the cURL command, please read the page, [Submit Annotation]({{site.baseurl}}/docs/submit-annotation/).