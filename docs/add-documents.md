---
layout: docs
title: Add Documents
prev_section: api
next_section: submit-annotations
permalink: /docs/add-documents/
---

Multiple documents can be added to you PubAnnotation projects by POSTing a list of document specifications to your projects.

## Example:

<input type="text" class="bash" value='curl -u "your_email_address:your_password" -H "content-type:application/json" -d &apos;{"docs":[{"source_db":"PubMed","source_id":"10022435"}]}&apos; http://pubannotation.org/projects/your_project_name/docs.json'>

* __[curl](http://curl.haxx.se/)__ : A linux command for transferring data using various protocols, e.g., HTTP.
  * __-u "your\_email\_address:your\_password"__ : tells curl to get authenticated using the information.
  * __-H "content-type:application/json"__ : tells curl to add the header in the request.
  * __-d '{"docs":[{"source_db":"PubMed","source_id":"10022435"}]}'__ : tells curl to send the specified data.
     * Note that the example is to add the document PubMed:10022435 to your project.
     * Note that "[...]" represents an array in JSON, and you can specify multiple document descriptors in it.
     * The JSON representation can be stored in a separate file, e.g., example.json, and you can specify the filename in the command: -d @example.json.
  * __http://pubannotation.org/projects/_your-project-name_/docs.json__ : The URL for the document list of your project.