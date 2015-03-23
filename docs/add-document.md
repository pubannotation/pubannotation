---
layout: docs
title: Adding documents
prev_section: create-project
next_section: create-annotation
permalink: /docs/add-document/
---

After creating your project, you can add documents to your project.

## Using Browser GUI

2. Go to your project page.
	> top > projects > your_project
3. If you are logged in, you will find the _add new documents_ form.
![add new document form]({{site.baseurl}}/img/add_new_documents.png)
4. Choose one of the pre-registered source DBs, e.g., _PubMed_ or _PMC_.
5. Write source IDs in the _source ID_ text box.
6. Click the _Add_ button.

## Using REST API

You can use any REST client to 'POST' a list of _document specifications_ to the document list of your project.

For example, [cURL](http://curl.haxx.se/) is a versatile command-line tool you can use as a REST client in any major OS, e.g., _UNIX_, _iOS_, _DOS_.

Following command shows an example usage of cURL:
<input type="text" class="bash" value='curl -u your_email_address:your_password -H "content-type:application/json" -d &apos;[{"sourcedb":"PubMed","sourceid":"123456"}]&apos; http://pubannotation.org/projects/your_project/docs/add.json'>

Following is explanation of the option specification:

* __-u "_your\_email\_address_:_your\_password_"__
   * Specifies your login information.
* __-H "content-type:application/json"__
   * Tells cURL to add the header in the request.
* __-d '[{"sourcedb":"PubMed","sourceid":"123"}]'__
   * Tells cURL to send (by the POST method) the data.
   * Note that the example is to add the document, _PubMed:12345_, to your project.
   * "[...]" means an array in JSON. You can specify multiple documents in it, e.g.,
     `[{"sourcedb":"PubMed","sourceid":"123"},{"sourcedb":"PMC","sourceid":"124"}]`
   * The JSON representation can be stored in a separate file, e.g., _example.json_, and you can 'POST' it by speficying the filename with a preceding at-sign(@), e.g., `-d @example.json`.
* __http://pubannotation.org/projects/_your-project_/docs/add.json__
   * The URL for adding new entries to the document list of your project.

Note that most recent major programming languages have modules for REST access, and you can do the same thing using any of your favorite programming languages.

