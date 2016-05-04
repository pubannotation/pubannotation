---
layout: docs
title: Creating documents
prev_section: import-document
next_section: create-annotation
permalink: /docs/create-document/
---

Once you have [created a project]({{site.baseurl}}/docs/create-project/) of your own,
you can add documents to the project for annotation.

There are three methods to add a document to a project:

1. [To _add_ a document from a pre-registered database]({{site.baseurl}}/docs/add-document/), e.g. _PubMed_ or _PMC_.
2. [To _import_ documents from an existing project]({{site.baseurl}}/docs/import-document/).
3. To _create_ a new document

This page explains the third method.

You can create a document by providing a block of text and relevant information, using one of following ways.

## Using Browser GUI

1. Go to your project page.
   * top > projects > your_project
2. If you are logged in, you will find the _create a new document_ menu.<br>
![create_document_form]({{site.baseurl}}/img/create_document.png)
3. Click the menu to open the _New document_ dialog.
4. Provide a block of text and relevant information, e.g. source URL.
If you are not sure about the relevant information, you can just the fields blank, and click the _Create document_ button.

## Using REST API

You can use any REST client, e.g. [cURL](http://curl.haxx.se/), to 'POST' a document to your project.

Note that most recent major programming languages have modules for REST access, and you can do the same thing using any of your favorite programming languages.

The following example shows a simple cURL command to create a new document in the project _your_project_:
<textarea class="bash" readonly="true" style="height:5em">
curl -u "your_email_address:your_password" text="This is a sample text." http://pubannotation.org/projects/your_project/docs.json
</textarea>
Following is explanation of the option specification:

* __-u "_your\_email\_address_:_your\_password_"__
   * Specifies your login information.
* __-d text="This is a sample text."__
   * Specifies the text to be _This is a sample text._.
* __http://pubannotation.org/projects/_your-project_/docs.json__
   * The URL for adding new entries to the document list of your project.
   * By adding the suffix _.json_ in the end, you can get the result message in JSON.

You can also send the text in JSON:
<textarea class="bash" readonly="true" style="height:7em">
curl -u "your_email_address:your_password" -H "content-type:application/json" -d &apos;{"text":"This is a sample text."}&apos; http://pubannotation.org/projects/your_project/docs.json
</textarea>

* __-H "content-type:application/json"__
   * Tells the server to interprete the body of the request as JSON.
* __-d '{"text":"This is a sample text"}'__
   * Tells cURL to send (by the POST method) the text in JSON.

Using JSON, you can send multiple document specifications:
<textarea class="bash" readonly="true" style="height:7em">
NOT YET IMPLEMENTED.
</textarea>
