---
layout: docs
title: Submit Annotations
prev_section: add-documents
next_section: about
permalink: /docs/submit-annotations/
---

You can add annotations to documents that are included in your project.

## Using Editor

1. Go to a document page of your project.
2. Open the editor. ([TextAE](http://textae.pubannotation.org) is the default editor of PubAnnotation.)
![open the editor]({{site.baseurl}}/img/open_editor.png)
3. Creat or edit annotations using the editor.
4. Save (or upload) the annotation.

## Using REST API

You can use any REST client to POST annotations to a document in your project.
For example, [cURL](http://curl.haxx.se/) is a versatile command-line tool you can use as a REST client in major OS environments, e.g., _UNIX_, _iOS_, _DOS_.

In fact, [TextAE](http://textae.pubannotation.org) is also a REST client that additionally provides graphical user interface for edition of annotation.

Also, most recent major programming languages have modules for REST access, so you can do it using your favorite programming languages.

Following command shows an example usage of cURL:
<input type="text" class="bash" value='curl -u your_email_address:your_password -H "content-type:application/json" -d @your_annotation_file.json "http://pubannotation.org/projects/your_project_name/docs/sourcedb/PubMed/sourceid/123456/annotations.json"
'>

Following is explanation of the option specification:

* __-u your\_email\_address_:_your\_password__
   * Specifies your login information. Login is required to protect your project: only you can add documents to your project.
* __-H "content-type:application/json"__
   * Tells cURL to add the header in the request.
* __-d @your\_annotation\_file.json__
   * Tells cURL to send the annotation data stored in the specified file.
   * To learn how to prepare an annotation data file, please refer to [Format]({{site.baseurl}}/docs/format/).
* __http://pubannotation.org/projects/_your-project-name_/docs/sourcedb/PubMed/sourceid/123456/annotations.json__
   * The URL for the document, _PubMed:123456_, in your project.
   * Note that the document needs to be included in advance.

