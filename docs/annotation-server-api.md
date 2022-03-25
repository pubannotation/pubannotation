---
layout: docs
title: Annotation server API
prev_section: obtain-annotation
next_section: annotation-editor
permalink: /docs/annotation-server-api/
---

Pubannotation can communicate with an external web service,
which we call an _annotation server_,
to get annotation from the server.

Currently, PubAnnotation can communicate with annotation servers 
which conforms the following input and output API.

### Input

For an annotation server to be interoperable with PubAnnotation, it has to take as input either

* a piece of text (through a parameter which defaults to _text_ ), or
* a pair of source DB and source ID specification (through parameters which defualt to _sourcedb_ and _sourceid_ ).

When a request is made with a piece of text,
the server is expected to produce annotation to the text,
and to respond with the annotation.

When a request is made with source DB / source ID specification,
the server is expected to fetch the corresponding piece of text from the source DB,
to produce annotation to the text,
and to respond with the annotation.

When a request is made with both a piece of text and a specification of source DB / source ID,
the former should take precedence, and the latter should be treated as redundant fields.

When a request is made with some redundant fields, the server is expected to ignore them for its processing, but to include all of them in the response.
In other words, when the server receives a request with a json object, it is expected return the json object as it is, changing only the annotation fields, e.g., denotations, relations, and modifications.

### Output

PubAnnotation expects an annotation server to respond with annotations represented in 
[PubAnnotation JSON format]({{site.baseurl}}/docs/annotation-format/).

For a server which supports content negotiation to determine the format of the response body,
PubAnnotation will add the header "_Accept: application/json_" to every request it will make.

### Asynchronous output

> [changes made at 21st Feb, 2017] The Retry-After header can be sent with the response of the initial request (not the second).

> [changes made at 21st Feb, 2017] For the second request, the response code for the case the result of annotation is not (yet) available is changed to 404 from 503.

> [changes made at 21st Feb, 2017] For the second request, the response code for the case the result of annotation is permanently removed is changed to 410 from 404.

The communication to get annotation from an annotation server can be made in an asyncronous way.
For example, sometimes, it may take a long time for a server to produce annotation,
and a request cannot be responded with the result of annotation within a reasonable time.

In the case, an initial request is made with the input parameters.
If the request is determined valid, the server is expected to respond with a status code 303 (See Other),
together with the _Location_ header to indicate the URL for retrieval of the annotation.
Optionally, the _Retry-After_ header can be used to indicate
how long the clinet is advised to wait before accessing the location of annotation result.

If the server cannot fulfil the request for some reason, e.g., server overload,
it has to respond with the status code 503 (Service Unavailable).
The motivation of use of the code is to inform the client that the request is fine,
and that a later attempt with the same request may be successful.
Optionally, the _Retry-After_ header can be used to indicate
how long the clinet is advised to wait before retry.

When the request to retrieve the result of annotation is made, if ready,
the server has to respond with the status code 200 (OK)
and the body has to deliver the result of annotation.

If the server is not ready with annotations,
it has to respond with the status code 404 (Not Found), _together with the Retry-After header_.

After annotations are delivered to the client, if the server removes the annotations,
the annotations will not be available any more from the server.
In the case, the server can respond with the status code 410 (Gone).

As a model implementation, the API for asynchronous annotation request and retrieval is implemented in PubDictionaries.
Please take a look at the corresponding API documentation: [PubDictionaries Annotation API](https://docs.pubdictionaries.org/annotation-api/)

## Registration of an annotation server

An annotation server can be registered to the [annotators](https://pubannotation.org/annotators) page of PubAnnotation.

Below is an example of registration for an annotation service by PubDictionaries using the dictionary _UBERON-AE_:
<br/>
![register_annotation_server]({{site.baseurl}}/img/register_annotation_server.png)
<br/>
Parameters can be customized using the resigration interface.
For details, please click the help icon of the interface.

Below is another example to register the same annotation service this time for batch annotation (100 documents in one batch):
<br/>
![register_annotation_server_batch]({{site.baseurl}}/img/register_annotation_server_batch.png)
<br/>


## Example of requests

For an annotation server to be interoperable with PubAnnotation,
it has to respond **at least one** of the example calls shown below.

Note that all the examples below are shown as [cURL](https://curl.haxx.se/) commands,
so that annotation servers can be easily tested.

Note also that PubAnnotation will add _"Accept:application/json"_ header to every request it will made,
so that annotation servers which implement content negotiation can respond with annotation in JSON format.
The servers which do not implement content negotiation can simply ignore the header.

### a POST request with a piece of text
<textarea class="bash" style="width:100%; height:3em; background-color:#333333; color:#eeeeee">
curl -d text="example text" URL_of_annotation_server
</textarea>

Note that when the _-d_ option is used to specify parameters, cURL will make it into a POST request.

### a GET request with a piece of text
<textarea class="bash" style="width:100%; height:3em; background-color:#333333; color:#eeeeee">
curl -G -d text="example text" URL_of_annotation_server
</textarea>

Note that the _-G_ option will force it to be a GET request: the parameter specification will be appended to the URL.

### a POST request with a piece of text (in JSON body)

<textarea class="bash" style="width:100%; height:3em; background-color:#333333; color:#eeeeee">
curl -H "Content-type:Application/json" -d '{"text":"example text"} URL_of_annotation_server
</textarea>

Note that the header _"Content-Type:application/json"_ is added to inform the annotation server that the body of the request is a JSON object.

Note that the three examples above essentially represent the same request in different ways.

### a POST request with _sourcedb_/_sourceid_ specification
<textarea class="bash" style="width:100%; height:3em; background-color:#333333; color:#eeeeee">
curl -d sourcedb="PubMed" -d sourceid="12345" URL_of_annotation_server
</textarea>

### a GET request with _sourcedb_/_sourceid_ specification
<textarea class="bash" style="width:100%; height:3em; background-color:#333333; color:#eeeeee">
curl -G -d sourcedb="PubMed" -d sourceid="12345" URL_of_annotation_server
</textarea>

### a POST request with _sourcedb_/_sourceid_ specification in JSON.
<textarea class="bash" style="width:100%; height:3em; background-color:#333333; color:#eeeeee">
curl -H "Content-type:Application/json" -d '{"sourcedb":"PubMed","sourceid":"12345"}'' URL_of_annotation_server
</textarea>
