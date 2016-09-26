---
layout: docs
title: Find text locations
prev_section: align-annotation
next_section: compare-project
permalink: /docs/find-location/
---

When you have a text excerpt from PubMed or PubMed Central (the Open Access subset),
and if you know the PubMed ID or PMC ID,
you can fined the location of the excerpt,
by simply posting the excerpt via the variable, 'text', to the 'spans' address of the document:
<input type="text" class="bash" value='curl -d text="text_excerpt" "http://pubannotation.org/docs/sourcedb/PubMed/sourceid/012345/spans.json"
'>
If the location is successfuly found, you will receive the URL of the excerpt,
with which you can access it with its full context. 
