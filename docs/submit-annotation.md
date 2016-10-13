---
layout: docs
title: Submitting annotations
prev_section: annotation-editor
next_section: align-annotation
permalink: /docs/submit-annotation/
---

You can deposit your annotations to PubAnnotation.

To do it,

1. First, __prepare your annotations in [JSON](http://json.org/)__ files, following the guidelines in [Format]({{site.baseurl}}/docs/annotation-format/).
Once an annotation file is prepared, your are recommended to open it in the [TextAE editor](http://textae.pubannotation.org/editor.html?mode=edit). Then, you will immediately see if the annotation file is well prepared as you intend or not.
2. __[Create an annotation project]({{site.baseurl}}/docs/create-project/)__ on PubAnnotation.
3. Then, you can store your annotations in your project.

## Submit annotations, method 1

You can use any REST client to POST annotations to a document in your project.
For example, [cURL](http://curl.haxx.se/) is a versatile command-line tool you can use as a REST client in major OS environments, e.g., _UNIX_, _iOS_, _DOS_.

In fact, [TextAE](http://textae.pubannotation.org) is also a REST client that additionally provides graphical user interface for edition of annotation.

Also, most recent major programming languages have modules for REST access, so you can do it using your favorite programming languages.

Following command shows an example usage of cURL:
<textarea class="bash" style="width:100%; height:6em; background-color:#333333; color:#eeeeee">
curl -u "your_email_address:your_password" -H "content-type:application/json" -d @your_annotation_file.json http://pubannotation.org/projects/your_project/docs/sourcedb/PubMed/sourceid/123456/annotations.json
</textarea>

Following is explanation of the option specification:

* __-u "_your\_email\_address_:_your\_password_"__
   * Specifies your login information.
* __-H "content-type:application/json"__
   * Tells cURL to add the header in the request.
* __-d @your\_annotation\_file.json__
   * Tells cURL to send the annotation data stored in the specified file.
   * To learn how to prepare an annotation data file, please refer to [Format]({{site.baseurl}}/docs/annotation-format/).
* __http://pubannotation.org/projects/_your-project_/docs/sourcedb/PubMed/sourceid/123456/annotations.json__
   * The URL for the document, _PubMed:123456_, in your project.

<div class="boxtip">
<b>Note</b> that the default behavior of submitting a set of annotations is <i>replacement</i>, meaning that the submitted set of annotations will <em>replace</em> the pre-existing annotations to the document. Alternatively, the behavior can be changed to <i>add</i> mode by giving the option <i>mode=add</i> in the end of the URL, e.g., <span class="console">.../annotations.json?mode=add</span>, which will add the submitted annotations, preserving the pre-existing ones.
</div>

## Submit annotations, method 2

Note that in the above method, the destination (the document) of the annotations is specified by two parameters, _sourcedb_ and _sourceid_, which are encoded in the URL.

Alternatively, you can encode the parameters in the annotation file, as a meta data of your annotation.
With it, the annotation file may look like as follows:
{% highlight json %}
{
   "text": "IRF-4 expression in CML may be induced by IFN-α therapy",
   "sourcedb": "PubMed",
   "sourceid": "123456",
   "denotations": [
      {"id": "T1", "span": {"begin": 0, "end": 5}, "obj": "Protein"},
      {"id": "T2", "span": {"begin": 42, "end": 47}, "obj": "Protein"}
   ]
}
{% endhighlight %}

Once the parameters are encoded in the annotation file, they do not need to be encoded again in the URL, and the cURL comman may be shortened as follows:
<textarea class="bash" style="width:100%; height:4em; background-color:#333333; color:#eeeeee">
curl -u "your_email_address:your_password" -H "content-type:application/json" -d @your_annotation_file.json http://pubannotation.org/projects/your_project/annotations.json
</textarea>

## Submit annotations, method 3 (batch upload)

When you have many annotation files to upload, 'POSTing' them individually may take a long time
because it requires HTTP connections to be made as many times as the number of files.

In the case, you can archive the annotation files in a __tgz__ file (gzip-compressed tar file),
and upload it. It will require an HTTP connection to be made only once per a tgz file.

<div class="boxtip">
<b>Note</b> The batch upload function has been found to be okay with tgz files up to the scale around 0.5 GB size with 1M PubMed abstracts, through a stress test. However, users are recommended to split their annotation files into smaller archive files than that, e.g. less than 250 MB with 0.5M abstracts.
</div>

Note that, for a bacth upload,
the '__sourcedb__' and '__sourceid__' (also '__divid__', see below) parameters
need to be encoded __in the annotation file__ as described in 'method 2'.

Once you are logged in, you can find the form for batch upload __in your project page__.

Once an annotation tgz file is uploaded,
a background job is created for alignment and storage of all the annotations in the file.
You can check the progress of a job in the __Jobs__ page,
for which the button will appear next to the title of a project if the project has at least one job.

<div class="boxtip">
<b>Note</b> During batch upload, there is a chance that you will see some error messages. A typical one is "<i>Failed to get the document</i>". It happens when PubAnnotation fails to get the article from the source DB. It sometimes happens when there is a connection problem or server problem with PubMed or PMC. If you see the message, you can simply collect the failed articles, and submit them again. In most cases, the problem will disappear. Another probable error message is "<i>Alignment failed. Text may be too much different</i>". The message is shown when the alignment algorithm of PubAnnotation determines that there is a chance of annotation loss during alignment process. If you see the message, please first check if your text is very different from the version in PubAnnotation. If you do not find particular problem in your text, please report the case to us (admin@pubannotation.org). Your report will be very useful for us to improve the alignment algorithm.
</div>



## Submit annotations to PMC documents (full papers)

As a full paper is long, PubAnnotation maintains a full paper in multiple divisions (divs).
When you upload annotations to a PMC document, you have two options.

### 1. POSTing annotations to a specific division

You can POST annotations to a specific division, e.g., 
`http://pubannotation.org/projects/your-project/docs/sourcedb/PMC/sourceid/123456/divs/0/annotations.json`

Note that, in URL, a division is specified as `divs/division_number`.

When it is encoded in a JSON file, it is specified as `"divid":division_number`, where _division_number_ is an integer value.

Below is an example:
{% highlight json %}
{
   "text": "IRF-4 expression in CML may be induced by IFN-α therapy",
   "sourcedb": "PMC",
   "sourceid": "123456",
   "divid": 10,
   "denotations": [
      {"id": "T1", "span": {"begin": 0, "end": 5}, "obj": "Protein"},
      {"id": "T2", "span": {"begin": 42, "end": 47}, "obj": "Protein"}
   ]
}
{% endhighlight %}

Note (again) that the value of "divid" is an integer value (without quotes around it).

### 2. POSTing annotations without specification of div
 
You can also POST annotations without specification of a division, e.g., 
`http://pubannotation.org/projects/your-project/docs/sourcedb/PMC/sourceid/123456/annotations.json`

In the case, the division will be automatically found base on the _text_ in your JSON file.

Note that it may take a bit of time (several minutes, sometimes).

Also, the text need to be reasonably long (at least, one or two sentences).

