# This seed only for development environment
return if Rails.env.production?

User.create! username: 'admin',
             email: 'admin@pubannotation.org',
             password: 'abc123',
             password_confirmation: 'abc123',
             confirmed_at: Time.now,
             root: true,
             manager: true

Project.create! name: 'First',
                user: User.first,
                accessibility: 1

# To Avoid initialize error, Create admin project.
# Note that if the id is missing teeth, the test will fail in a CI environment.
i = 0
loop do
  project = Project.create! name: "ForAdmin#{i}",
                            user: User.first,
                            accessibility: 0
  i += 1
  break if project.id == Pubann::Admin::ProjectId
end

Sequencer.create! name: 'PMC',
                  url: 'http://pubmed-sequencer.pubannotation.org/?sourcedb=PMC',
                  parameters: { 'sourceid' => '_sourceid_' },
                  user: User.first

Sequencer.create! name: 'PubMed',
                  url: 'https://pubmed-sequencer.pubannotation.org/?sourcedb=PubMed',
                  parameters: { 'sourceid' => '_sourceid_' },
                  user: User.first

doc = Doc.create! sourcedb: 'PMC',
                  sourceid: 'PMC0000001',
                  body: <<~BODY
                        I am happy to join with you today in what will go down in history as the greatest demonstration for freedom in the history of our nation.

                        Five score years ago, a great American, in whose symbolic shadow we stand today, signed the Emancipation Proclamation. This momentous decree came as a great beacon light of hope to millions of Negro slaves who had been seared in the flames of withering injustice. It came as a joyous daybreak to end the long night of their captivity.

                        But one hundred years later, the Negro still is not free. One hundred years later, the life of the Negro is still sadly crippled by the manacles of segregation and the chains of discrimination. One hundred years later, the Negro lives on a lonely island of poverty in the midst of a vast ocean of material prosperity. One hundred years later, the Negro is still languished in the corners of American society and finds himself an exile in his own land. And so we've come here today to dramatize a shameful condition.
                        BODY
project = doc.projects.create! name: 'Dream',
                     user: User.first,
                     accessibility: 1
t1 = Denotation.create! doc: doc, project: project, hid: 'T1', begin: 58, end: 65, obj: 'history'
t2 = Denotation.create! doc: doc, project: project, hid: 'T2', begin: 115, end: 122, obj: 'history'
t3 = Denotation.create! doc: doc, project: project, hid: 'T3', begin: 169, end: 177, obj: "nation"
t4 = Denotation.create! doc: doc, project: project, hid: 'T4', begin: 866, end: 874, obj: 'nation'
t5 = Denotation.create! doc: doc, project: project, hid: 'T5', begin: 5, end: 10, obj: 'emotion'
t6 = Denotation.create! doc: doc, project: project, hid: 'T6', begin: 332, end: 337, obj: 'Negro'
t7 = Denotation.create! doc: doc, project: project, hid: 'T7', begin: 508, end: 513, obj: 'Negro'
t8 = Denotation.create! doc: doc, project: project, hid: 'T8', begin: 574, end: 578, obj: 'Negro'
t9 = Denotation.create! doc: doc, project: project, hid: 'T9', begin: 698, end: 703, obj: 'Negro'
t10 = Denotation.create! doc: doc, project: project, hid: 'T10', begin: 822, end: 827, obj: 'Negro'
Attrivute.create! doc: doc, project: project, hid: 'A1', subj: t5, pred: 'emotion', obj: true
Attrivute.create! doc: doc, project: project, hid: 'A2', subj: t6, pred: 'role', obj: 'default'
Attrivute.create! doc: doc, project: project, hid: 'A3', subj: t7, pred: 'role', obj: 'default'
doc.divisions.create! begin: 0, end: 137, label: 'p'
doc.divisions.create! begin: 139, end: 473, label: 'p'
doc.divisions.create! begin: 475, end: 990, label: 'p'
doc.blocks.create! project: project, hid: 'B1', begin: 0, end: 137, obj: 'Sentence'
doc.blocks.create! project: project, hid: 'B2', begin: 139, end: 257, obj: 'Sentence'
doc.blocks.create! project: project, hid: 'B3', begin: 258, end: 304, obj: 'Sentence'
doc.blocks.create! project: project, hid: 'B4', begin: 305, end: 473, obj: 'Sentence'
doc.blocks.create! project: project, hid: 'B5', begin: 475, end: 522, obj: 'Sentence'
doc.blocks.create! project: project, hid: 'B6', begin: 523, end: 658, obj: 'Sentence'
doc.blocks.create! project: project, hid: 'B7', begin: 659, end: 792, obj: 'Sentence'
doc.blocks.create! project: project, hid: 'B8', begin: 793, end: 990, obj: 'Sentence'

Editor.create! user: User.first,
               is_public: true,
               name: 'TextAE',
               url: 'http://textae.pubannotation.org/editor.html?mode=edit',
               parameters: { 'source' => '_annotations_url_' }

Annotator.create! user: User.first,
                  is_public: true,
                  name: 'PD-UBERON-AE-2023',
                  url: 'https://pubdictionaries.org/text_annotation.json?dictionary=UBERON-AE-2023&threshold=0.92&abbreviation=true&longest=true',
                  method: 1,
                  payload: { '_body_' => '_doc_' },
                  max_text_size: 50000,
                  receiver_attribute: 'uberon_id',
                  new_label: 'Body_part',
                  sample: 'We have shown that synthetic multivalent sialyl Lewis x glycans inhibit strongly the adhesion of lymphocytes to endothelium at sites of inflammation.'

doc2 = Doc.create! sourcedb: 'PMC',
                   sourceid: 'PMC0000002',
                   body: <<~BODY
We have shown that synthetic multivalent sialyl Lewis x glycans inhibit strongly the adhesion of lymphocytes to endothelium at sites of inflammation.
BODY

doc2.projects << Project.first

pubmed_doc = Doc.create! sourcedb: 'PubMed',
            sourceid: '35745860',
            body: <<~BODY
                  CYP2C19 rs4986893 (c.636G > A) is a loss-of-function mutation with predicted higher substrate concentrations as well.
                  Although we had only one patient in our population heterozygous for this variant, we considered it in the final model.
                  The resulting Ctrough-increasing effect was in agreement with the expectation.
                  Omitting this polymorphism had no major impact on the final model.

                  CYP2C19 rs12248560 g.-806C > T is associated with accelerated metabolism, which we could not confirm in any of our tested models, including the final model.
                  Espinoza et al. came to a contrary conclusion in a study with immunocompromised children.
                  In their study, the averaged Ctrough was lower in carriers than non-carriers.
                  However, as the authors discussed themselves, they did not exclude potential carriers of reduced-function CYP2C19 polymorphisms from the control group for the comparison, leaving the question unanswered whether the difference was due to the rs12248560 genotype or due to other polymorphisms in the control group (in addition).

                  Whether the rs12248560 mutation in the promotor region results in increased CYP2C19 expression in children as observed in adults remains to be shown.
                  Our data from 9 heterozygous carriers (compared to 14 non-carriers) would not suggest that.
                  BODY

pubmed_project = pubmed_doc.projects.create! name: 'PubMed_Project',
                                             user: User.first,
                                             accessibility: 1
