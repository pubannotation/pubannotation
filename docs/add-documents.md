---
layout: docs
title: Add Documents
prev_section: api
next_section: submit-annotations
permalink: /docs/add-documents/
---

After creating your project, you can add documents to your project.

## Using Browser GUI

1. Be sure that you are logged in.
2. Go to the document page of your project.
	> top > projects > your_project > docs
3. Find the _add new document_ form at the bottom of the page.
![add new document form]({{site.baseurl}}/img/add_new_documents.png)
4. Choose one of the pre-registered source DB, e.g., _PubMed_ or _PMC_.
5. Write source IDs in the _source ID_ text box.
6. Click the _Add_ button.

## Using REST API

You can use any REST client to POST a list of _document specifications_ to the document list of your project.
For example, [cURL](http://curl.haxx.se/) is a versatile command-line tool you can use as a REST client in major OS environments, e.g., _UNIX_, _iOS_, _DOS_.

Following command shows an example usage of cURL:
<input type="text" class="bash" value='curl -u your_email_address:your_password -H "content-type:application/json" -d &apos;{"docs":[{"source_db":"PubMed","source_id":"123456"}]}&apos; http://pubannotation.org/projects/your_project_name/docs.json'>

Following is explanation of the option specification:

* __-u your\_email\_address_:_your\_password__
   * Specifies your login information. Login is required to protect your project: only you can add documents to your project.
* __-H "content-type:application/json"__
   * Tells cURL to add the header in the request.
* __-d '{"docs":[{"source\_db":"PubMed","source\_id":"123456"}]}'__
   * Tells cURL to send the specified data.
   * Note that the example is to add the document, _PubMed:10022435_, to your project.
   * "[...]" means an array in JSON, and you can specify multiple documents in it, e.g.,
     `[{"source_db":"PubMed","source_id":"123"},{"source_db":"PMC","source_id":"456"}]`
   * The JSON representation can be stored in a separate file, e.g., example.json, and you can specify the filename by prefixing it with the at-sign(@), e.g., `-d @example.json`.
* __http://pubannotation.org/projects/_your-project-name_/docs.json__
   * The URL for the document list of your project.
