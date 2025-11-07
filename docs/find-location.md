---
layout: docs
title: Find text locations
prev_section: align-annotation
next_section: evaluate-annotations
permalink: /docs/find-location/
---

When you have a text excerpt from PubMed or PubMed Central (the Open Access subset),
and if you know the PubMed ID or PMC ID,
you can find the location of the excerpt,
by simply posting the excerpt to the 'find_location' endpoint:
<input type="text" class="bash" value='curl -d text="text_excerpt" "http://pubannotation.org/docs/sourcedb/PubMed/sourceid/012345/spans/find_location.json"'>
or its project-specific version.
<input type="text" class="bash" value='curl -d text="text_excerpt" "http://pubannotation.org/projects/project_name/docs/sourcedb/PubMed/sourceid/012345/spans/find_location.json"'>
If the location is successfuly found, you will receive the URL of the excerpt,
with which you can access the excerp with its full context.
