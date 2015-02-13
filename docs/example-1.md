---
layout: docs
title: Example 1
prev_section: align-annotation
next_section: about
permalink: /docs/example-1/
---

This example shows how you can use PubAnnotation to align your annotation into the original text.

Suppose you once took a sentence from the PubMed abstract 25314077 and annotated it for gene names using Entrez Gene IDs as follows:

<div class="textae-editor">
{"text":"Here, we identify the interaction between the NF-kappaB-regulated antiapoptotic factor GADD45beta and the JNK kinase MKK7 as a therapeutic target in MM.","denotations":[{"id":"T1","span":{"begin":46,"end":55},"obj":"Gene:4790"},{"id":"T2","span":{"begin":87,"end":97},"obj":"Gene:4616"},{"id":"T3","span":{"begin":117,"end":121},"obj":"Gene:5609"},{"id":"T4","span":{"begin":106,"end":109},"obj":"Gene:5599"}]}
</div>

Its JSON encoding may look like as follows (indented for easy of reading):

<pre style="white-space:pre-wrap; background:black; color:white">
{
"text":"Here, we identify the interaction between the NF-kappaB-regulated antiapoptotic factor GADD45beta and the JNK kinase MKK7 as a therapeutic target in MM.",
"denotations":[
	{"id":"T1","span":{"begin":46,"end":55},"obj":"Gene:4790"},
	{"id":"T2","span":{"begin":87,"end":97},"obj":"Gene:4616"},
	{"id":"T3","span":{"begin":117,"end":121},"obj":"Gene:5609"},
	{"id":"T4","span":{"begin":106,"end":109},"obj":"Gene:5599"}
]
}
</pre>

Suppose you've stored the annotation in the json file, <em>PubMed-25314077-gene.json</em>.
You can open the file in the [TextAE editor](http://textae.pubannotation.org/editor.html?mode=edit).

Now you want to examine the whole abstract, and for tht you want to bring the annotation into the source abstract.
To do it, you first need to find the location of the sentence in the abstract,
then update the position indice (<em>begin</em> and <em>end</em>) of the annotation.
Below is the abstract as extracted from PubMed. Note that the sentence is highlighted for convenience of reading:

<fieldset>
<legend>PubMed:25314077</legend>
Cancer-selective targeting of the NF-κB survival pathway with GADD45β/MKK7 inhibitors.
Constitutive NF-κB signaling promotes survival in multiple myeloma (MM) and other cancers; however, current NF-κB-targeting strategies lack cancer cell specificity. <b>Here, we identify the interaction between the NF-κB-regulated antiapoptotic factor GADD45β and the JNK kinase MKK7 as a therapeutic target in MM.</b> Using a drug-discovery strategy, we developed DTP3, a D-tripeptide, which disrupts the GADD45β/MKK7 complex, kills MM cells effectively, and, importantly, lacks toxicity to normal cells. DTP3 has similar anticancer potency to the clinical standard, bortezomib, but more than 100-fold higher cancer cell specificity in vitro. Notably, DTP3 ablates myeloma xenografts in mice with no apparent side effects at the effective doses. Hence, cancer-selective targeting of the NF-κB pathway is possible and, at least for myeloma patients, promises a profound benefit.
</fieldset>

With PubAnnotation, the task is very easy to accomplish.
You can just send the json file to PubAnnotation as follows:

<textarea class="bash" style="width:100%; height:4em">curl -H "content-type:application/json" -d @PubMed-25314077-gene.json http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations.json > PubMed-25314077-gene-aligned.json</textarea>

The above command uses the [cURL](http://curl.haxx.se/) tool

- to send (by the <em>HTTP POST</em> method) the file, <em>PubMed-25314077-gene.json</em>,
- to the URL, <em>http://pubannotation.org/docs/sourcedb/PubMed/sourceid/25314077/annotations.json</em>,
- then stores the output to the file, <em>PubMed-25314077-gene-aligned.json</em>

Below is the result of the cURL command:

<fieldset>
<legend>PubMed:25314077</legend>
{"text":"Cancer-selective targeting of the NF-κB survival pathway with GADD45β/MKK7 inhibitors.\nConstitutive NF-κB signaling promotes survival in multiple myeloma (MM) and other cancers; however, current NF-κB-targeting strategies lack cancer cell specificity. Here, we identify the interaction between the NF-κB-regulated antiapoptotic factor GADD45β and the JNK kinase MKK7 as a therapeutic target in MM. Using a drug-discovery strategy, we developed DTP3, a D-tripeptide, which disrupts the GADD45β/MKK7 complex, kills MM cells effectively, and, importantly, lacks toxicity to normal cells. DTP3 has similar anticancer potency to the clinical standard, bortezomib, but more than 100-fold higher cancer cell specificity in vitro. Notably, DTP3 ablates myeloma xenografts in mice with no apparent side effects at the effective doses. Hence, cancer-selective targeting of the NF-κB pathway is possible and, at least for myeloma patients, promises a profound benefit.","denotations":[{"id":"T1","span":{"begin":298,"end":303},"obj":"Gene:4790"},{"id":"T2","span":{"begin":335,"end":342},"obj":"Gene:4616"},{"id":"T3","span":{"begin":362,"end":366},"obj":"Gene:5609"},{"id":"T4","span":{"begin":351,"end":354},"obj":"Gene:5599"}]}
</fieldset>

Below is the [TextAE](http://textae.pubannotation.org) rendering of it:

<div class="textae-editor">
{"text":"Cancer-selective targeting of the NF-\u03baB survival pathway with GADD45\u03b2/MKK7 inhibitors.\nConstitutive NF-\u03baB signaling promotes survival in multiple myeloma (MM) and other cancers; however, current NF-\u03baB-targeting strategies lack cancer cell specificity. Here, we identify the interaction between the NF-\u03baB-regulated antiapoptotic factor GADD45\u03b2 and the JNK kinase MKK7 as a therapeutic target in MM. Using a drug-discovery strategy, we developed DTP3, a D-tripeptide, which disrupts the GADD45\u03b2/MKK7 complex, kills MM cells effectively, and, importantly, lacks toxicity to normal cells. DTP3 has similar anticancer potency to the clinical standard, bortezomib, but more than 100-fold higher cancer cell specificity in vitro. Notably, DTP3 ablates myeloma xenografts in mice with no apparent side effects at the effective doses. Hence, cancer-selective targeting of the NF-\u03baB pathway is possible and, at least for myeloma patients, promises a profound benefit.","denotations":[{"id":"T6","span":{"begin":298,"end":303},"obj":"Gene:4790"},{"id":"T7","span":{"begin":335,"end":342},"obj":"Gene:4616"},{"id":"T9","span":{"begin":362,"end":366},"obj":"Gene:5609"},{"id":"T8","span":{"begin":351,"end":354},"obj":"Gene:5599"}]}
</div>