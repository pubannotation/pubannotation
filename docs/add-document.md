---
layout: docs
title: Adding documents
prev_section: create-project
next_section: create-document
permalink: /docs/add-document/
---

Once you have [created a project]({{site.baseurl}}/docs/create-project/) of your own,
you can add documents to the project for annotation.

There are two methods to add a document to a project:

1. To _import_ a document from a pre-registered database, e.g. _PubMed_ or _PMC_.
2. [To _create_ a new document.]({{site.baseurl}}/docs/create-document/)

This page explains the first method.
For the second method, readers are referred to [creating documents]({{site.baseurl}}/docs/create-document/).

You can import a document from a pre-registered database by providing a _document specification_ (a pair of the source (_sourcedb_) and the id (_sourceid_) of the document), using one of the following ways.

## Using Browser GUI

2. Go to your project page.
   * top > projects > your_project
3. If you are logged in, you will find the _add new documents_ form.
![add new document form]({{site.baseurl}}/img/add_new_documents.png)
4. Choose one of the pre-registered source DBs, e.g., _PubMed_ or _PMC_.
5. Write source IDs in the _source ID_ text box.
6. Click the _Add_ button.

## Using REST API

You can use any REST client, e.g. [cURL](http://curl.haxx.se/), to 'POST' a document specification or a list of _document specifications_ to your project.

Note that most recent major programming languages have modules for REST access, and you can do the same thing using any of your favorite programming languages.

The following example shows a cURL command to include the document PubMed:123456 in the project _your_project_:
<textarea class="bash" readonly="true" style="height:5em">
curl -u your_email_address:your_password -d sourcedb=PubMed -d sourceid=123 http://pubannotation.org/projects/your_project/docs/add.json
</textarea>
Following is explanation of the option specification:

* __-u "_your\_email\_address_:_your\_password_"__
   * Specifies your login information.
* __-d sourcedb=PubMed__
   * Specifies the sourcedb to be _PubMed_.
* __-d sourceid=1234546__
   * Specifies the sourceid to be _123456_.
* __http://pubannotation.org/projects/_your-project_/docs/add.json__
   * The URL for adding new entries to the document list of your project.
   * By adding the suffix _.json_ in the end, you can get the result message in JSON.

You can also send the document specification in JSON:
<textarea class="bash" readonly="true" style="height:7em">
curl -u your_email_address:your_password -H "content-type:application/json" -d &apos;{"sourcedb":"PubMed","sourceid":"123"}&apos; http://pubannotation.org/projects/your_project/docs/add.json
</textarea>

* __-H "content-type:application/json"__
   * Tells the server to interprete the body of the request as JSON.
* __-d '{"sourcedb":"PubMed","sourceid":"123"}'__
   * Tells cURL to send (by the POST method) the document specification in JSON.

Using JSON, you can send multiple document specifications:
<textarea class="bash" readonly="true" style="height:7em">
curl -u your_email_address:your_password -H "content-type:application/json" -d &apos;[{"sourcedb":"PubMed","sourceid":"123"},{"sourcedb":"PubMed","sourceid":"456"}]&apos; http://pubannotation.org/projects/your_project/docs/add.json
</textarea>

* __-d '[{"sourcedb":"PubMed","sourceid":"123"},{"sourcedb":"PubMed","sourceid":"456"}]'__
   * Tells cURL to send (by the POST method) the document specifications in JSON.
   * "[...]" means an array in JSON.

When you have a long list of document specifications, you can put it in a separate file, then specify the filename in the cURL command:
<textarea class="bash" readonly="true" style="height:5em">
curl -u your_email_address:your_password -H "content-type:application/json" -d @filename.json http://pubannotation.org/projects/your_project/docs/add.json
</textarea>

* __-d @filename.json__
   * Tells cURL to send the content of the file _filename.json_.
