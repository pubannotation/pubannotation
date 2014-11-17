---
layout: docs
title: Submit Annotations
prev_section: add-documents
next_section: about
permalink: /docs/submit-annotations/
---

Annotations to a document can be submitted to your project by POSTing a JSON file to your project.

## Example:

<input type="text" class="bash" value='curl -u your_email_address:your_password -H "content-type:application/json" -d @your_annotation_file.json "http://pubannotation.org/projects/your_project_name/docs/sourcedb/PubMed/sourceid/123456/annotations.json"
'>

* __[curl](http://curl.haxx.se/)__ : A linux command for transferring data using various protocols, e.g., HTTP.
  * __-u "your\_email\_address:your\_password"__ : tells curl to get authenticated using the information.
  * __-H "content-type:application/json"__ : tells curl to add the header in the request.
  * __-d @your_annotation_file.json__ : tells curl to send the data in the specified file.
  * __http://pubannotation.org/projects/_your-project-name_/docs/sourcedb/PubMed/sourceid/123456/annotations.json__ : The URL for the document, PubMed:123456, in your project.
     * Note that the document needs to be included in advance.

