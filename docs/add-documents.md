---
layout: docs
title: Add Documents
prev_section: api
next_section: about
permalink: /docs/add-documents/
---

Multiple documents can be added to you PubAnnotation projects by POSTing a list of document specifications to your projects.

## Example:
{% highlight bash %}
curl -u your_email_account@example.org:your_password -H "content-type:application/json" -d '{"docs":[{"source_db":"pubmed","source_id":"10022435"},{"source_db":"pmc","source_id":"1447668"}]}' http://pubannotation.org/projects/your_project_name/docs.json
{% endhighlight %}

