---
layout: docs
title: Submit Annotations
prev_section: add-documents
next_section: about
permalink: /docs/submit-annotations/
---

Annotations to a document can be submitted to your project by POSTing a JSON file to your projects.

## Example:
{% highlight bash %}
curl -u your_email_account@example.org:your_password -H "content-type:application/json" -d @your_annotation_file.json "http://pubannotation.org/projects/your_project_name/docs/sourcedb/pubmed/sourceid/123456/annotations.json"
{% endhighlight %}


