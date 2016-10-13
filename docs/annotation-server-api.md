---
layout: docs
title: Annotation server API
prev_section: obtain-annotation
next_section: annotation-editor
permalink: /docs/annotation-server-api/
---

PubAnnotation defines REST API for interoperability

A PubAnnotation-interoperable _annotations server_ is defined as a RESTful web service 
which conforms the following input and output API.

## Input

A PubAnnotation-interoperable annotation server takes either

* a piece of text through the parameter, _text_, or
* a pair of source DB and source ID specification through the parameter, _sourcedb_ and _sourceid_.

When a request is made with _text_,
the server is expected to produce annotations to the text,
and to respond with the annotations.

When a request is made with _sourcedb_/_sourceid_,
the server is expected to fetch the corresponding piece of text from the source DB,
to produce annotations to the text,
and to respond with the annotations.

Making a request with both _text_ and _sourcedb_/_sourceid_ may cause a redundant specification.
In the case, it is expected that the _text_ parameter takes higher priority
with the _sourcedb_/_sourceid_ specification ignored.

## Output

PubAnnotation expects an annotation server to respond with annotations represented in 
[PubAnnotation JSON format]({{site.baseurl}}/docs/annotation-format/).

In case an annotation server wants to support multiple representations of annotations,
the format of response body the client will expect may be represented in the URL itself or
in the _Accept_ header.

While different people advocate different approach, there may be pros and cons in both:
see this [dicussion](http://programmers.stackexchange.com/questions/139654/rest-tradeoffs-between-content-negotiation-via-accept-header-versus-extensions).

However, either should be fine with PubAnnotation.

For the case where a server replies on _Accept_ header to determine the output format of annotations.
PubAnnotation will add the _Accept_ header to every requests it will make.

In case a server see the URL, e.g. type extention, to determine the format of output, which is the case of PubAnnotation, the server can simply ignore the _Accept_ header.

## Asyncronous output

In case an annotation server requires a separate request for retrieval of annotations,
the server has to response to the initial request
with the status code 303 (See Other)
and the _Location_ header should contain the URL for the client to access to retrieve the annotations.

When the second request is made, if ready, the server has to respond with the status code 200 (OK)
and the body should contain annotations.

If the server is not ready with annotations, it has to respond with the status code 503 (Service Unavailable).
If possible, the _Retry-After_ header should contain the estimated time before ready.

After annotations are delivered to the client, if the server removes the annotations,
the annotations will not be available any more from the server.
In the case, it has to respond to the request for the annotations with the status code 404 (Bad request).

## Example

For an annotation server to be interoperable with PubAnnotation,
it has to respond **at least one** of the example calls shown below.

Note that all the examples below are shown as [cURL](http://curl.haxx.se/) commands,
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
