---
layout: docs
title: Simple Inline Annotation Format
prev_section: annotation-format
next_section: import-annotation
permalink: /docs/simple-inline-annotation-format/
---

It is a lightweight and intuitive solution for text annotation. Its syntax aligns seamlessly with Markdown conventions, ensuring compatibility with existing Markdown editors and general text editors, making annotations easy to create, edit, and maintain.

## Syntax Rules

1. Annotation Structure

   * An annotation is represented by two consecutive pairs of square brackets:

     * The first pair contains the annotated text.

     * The second pair contains the label.

   * Example: \[Annotated Text\]\[Label\]

   * It aligns with Markdown's syntax for reference-style links.

2. Metacharacter Escaping

   * The annotation structure (two consecutive pairs of square brackets) is unlikely to appear in normal text but is not entirely impossible. If it does occur, it may be misinterpreted as an annotation. To avoid this, the first opening square bracket must be escaped with a backslash (\\).

   * Example: \\\[This is a part of\]\[original text\]


## Example

| Format | Annotation |
| :---- | :---- |
| Inline | \[Elon Musk\]\[Person\] is a member of the \[PayPal Mafia\]\[Organization\]. |
| JSON | {“denotations”:\[{“span”:{“begin”: 0, “end”: 9}, “obj”:”Person”},    {“span”:{“begin”: 29, “end”: 41}, “obj”:”Organization”}\]} |


## Conversion

[TextAE](https://textae.pubannotation.org) supports the simple inline annotation format.

[PubAnnotation](https://pubannotation.org) provides APIs for conversion between the inline and JSON formats.

### Endpoint: POST /conversions/inline2json

Request:

- Content-Type header: Must be text/plain (required)
- Body: The inline annotated text (plain text in the request body)
 - Format: [text][label] inline annotation syntax
 - Example: [Elon Musk][Person] is a member of the PayPal Mafia.
 - Max size: 10 MB

Response:

- Returns JSON representation of the parsed annotations (using SimpleInlineTextAnnotation.parse)

Example usage:

{% highlight bash %}
curl -X POST https://pubannotation.org/conversions/inline2json \
 -H "Content-Type: text/plain" \
 -d "[Elon Musk][Person] is a member of the [PayPal Mafia][Organization]."
{% endhighlight %}

Error codes:

- 415 - Missing or invalid Content-Type (must be text/plain)
- 413 - Payload too large (exceeds 10 MB)
- 500 - Parse error

### Endpoint: POST /conversions/json2inline

Request:

- Content-Type header: Must be application/json (required)
- Body: JSON representation of annotations (PubAnnotation JSON format)

Response:

- Returns plain text with inline annotations (using SimpleInlineTextAnnotation.generate)
- Format: [text][label] inline annotation syntax

Example usage:

{% highlight bash %}
curl -X POST https://pubannotation.org/conversions/json2inline \
  -H "Content-Type: application/json" \
  -d '{"text":"Elon Musk is a member of the PayPal Mafia.","denotations":[{"span":{"begin":0,"end":9},"obj":"Person"}]}'
{% endhighlight %}

Error codes:

- 415 - Missing or invalid Content-Type (must be application/json)
- 400 - Invalid JSON or generation error
- 500 - Internal server error


## Prompt for LLMs

<pre style="white-space: pre-wrap;">
Text annotations are formatted using the Simple Inline Annotation format, where each annotation is represented by a pair of square brackets for the annotated text, immediately followed by another pair of square brackets for the label. Example: : [Annotated Text][Label]. Square brackets should not be nested. This format aligns with Markdown's syntax for reference-style links. To ensure correct parsing, any meta-characters in the text must be escaped beforehand. While the annotation structure (two consecutive pairs of square brackets) is unlikely to occur naturally in regular text, it is not entirely impossible. If such a case arises, it could be misinterpreted as an annotation. To prevent this, the first opening square bracket must be escaped with a backslash (\). Example: \[This is a part of][original text]. To display annotations, use the BTS (Bold-Text Square Brackets) Rendering. In this format, annotated text is displayed in bold to indicate the span, and the label is shown in square brackets immediately following the annotated text.
</pre>