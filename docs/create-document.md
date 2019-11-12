---
layout: docs
title: Creating documents
prev_section: import-document
next_section: add-annotation
permalink: /docs/create-document/
---

Once you have [created a project]({{site.baseurl}}/docs/create-project/) of your own,
the next step you would like to do is to add documents to the project.

There are three ways to add documents to a project:

1. [To _add_ documents from a pre-registered database]({{site.baseurl}}/docs/add-document/), e.g. _PubMed_ or _PMC_.
2. [To _import_ documents from an existing project]({{site.baseurl}}/docs/import-document/).
3. To _create_ a new document

This page explains the third method.

You can create a document by providing PubAnnotation with a block of text and relevant information, using one of following ways.

## Using Browser GUI

1. Go to your project page.
   * top > projects > your_project
2. If you are logged in, you will find the _create a new document_ menu.<br>
![create_document_form]({{site.baseurl}}/img/create_document.png)
3. Click the menu to open the _New document_ dialog.
4. Enter a block of text in the _Text_ field.
5. Enter relevant information, e.g. source URL. If you are not sure about the relevant information, you can just leave them blank.
6. Click the _Create document_ button.

## Using REST API

You can use any REST client, e.g. [cURL](http://curl.haxx.se/), to 'POST' a document to your project.

Note that most recent major programming languages have modules for REST access, and you can do the same thing using any of your favorite programming languages.

The following example shows a simple cURL command to create a new document in the project _your_project_:
<textarea class="bash" readonly="true" style="height:5em">
curl -u "your_email_address:your_password" -F text="This is a sample text." -F sourcedb="TestDocs" -F sourceid="1" http://pubannotation.org/projects/your_project/docs.json
</textarea>
Following is explanation of the option specification:

* __-u "_your\_email\_address_:_your\_password_"__
   * Specifies your login information.
   * You can omit the password part. Then, cURL will ask you for the password.
* __-F text="This is a sample text."__
   * Specifies the text to be _This is a sample text._.
   * If you want, you can tell it to read the text from a file, by prefixing the file name with the symbol '<',
     * e.g., -F "text=&lt;a_file_name". 
* __-F sourcedb="TestDocs"__
   * Specifies the sourcedb of the text to be _TextDocs_.
   * It is optional.
* __-F sourceid="1"__
   * Specifies the sourceid of the text to be _1_.
   * It is optional.
* __http://pubannotation.org/projects/_your-project_/docs.json__
   * The URL for adding new entries to the document list of your project.
   * By adding the suffix _.json_ in the end, you can get the response in JSON.

You can also send the text in JSON:
<textarea class="bash" readonly="true" style="height:7em">
curl -u "your_email_address:your_password" -H "content-type:application/json" -d &apos;{"text":"This is a sample text."}&apos; http://pubannotation.org/projects/your_project/docs.json
</textarea>

* __-H "content-type:application/json"__
   * Tells the server to interprete the body of the request as JSON.
* __-d '{"text":"This is a sample text"}'__
   * Tells cURL to send (by the POST method) the text in JSON.

The above examples do not specify the sourcedb and sourceid.
In such a case. the sourcedb will be set to be _@your_username_, and the sourceid to be the smallest integer that does not already exist as a sourceid within the sourcedb.

If you want, you can also specify the sourcedb and the sourceid as you like.
However, the sourcedb has to be prefixed with your username, e.g., _sourcedb_name@your_username_:
<textarea class="bash" readonly="true" style="height:7em">
curl -u "your_email_address:your_password" -H "content-type:application/json" -d &apos;{"sourcedb":"your_sourcedb@your_username", "text":"This is a sample text."}&apos; http://pubannotation.org/projects/your_project/docs.json
</textarea>

Using JSON, you can send multiple document specifications:
<textarea class="bash" readonly="true" style="height:7em">
NOT YET IMPLEMENTED.
</textarea>
