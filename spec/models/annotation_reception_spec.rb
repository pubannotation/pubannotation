# spec/models/annotation_reception_spec.rb
require 'rails_helper'

RSpec.describe AnnotationReception, type: :model do
  describe '#process_annotation!' do
    let(:annotator) { create(:annotator) }
    let(:project) { create(:project) }
    let(:job) { create(:job) }
    let(:options) { {  } }
    let(:annotation) {
      {
        "sourcedb":"PubMed",
        "sourceid":"21775533",
        "text":"Among 157 successfully genotyped SNPs, 9 and 10 SNPs were top SNPs associated with OS for patients with NSCLC and SCLC, respectively, although they were not significant after adjusting for multiple testing. Fifteen genes, including 7 located within 200 kb up or downstream of the four top SNPs and 8 genes for which expression was correlated with three SNPs in LCLs were selected for siRNA screening. Knockdown of DAPK3 and METTL6, for which expression levels were correlated with the rs11169748 and rs2440915 SNPs, significantly decreased cisplatin sensitivity in lung cancer cells.",
        "denotations":[{"id":"10701","span":{"begin":485,"end":495},"obj":"SNP"},{"id":"10704","span":{"begin":500,"end":509},"obj":"SNP"}],
        "attributes":[{"id":"A10701","subj":"10701","pred":"resolved_to","obj":"tmVar:rs11169748;VariantGroup:20;RS#:11169748"},{"id":"A10704","subj":"10704","pred":"resolved_to","obj":"tmVar:rs2440915;VariantGroup:12;RS#:2440915"}]
      }
    }
    let(:annotations_collection) { [annotation] }
    let(:doc) { project.docs.create!(sourcedb: annotation[:sourcedb], sourceid: annotation[:sourceid], body: annotation[:text]) }
    # span is a parameter for handling long documents by splitting them. Omitted this time.
    let(:hdoc_metadata) { [{ docid: doc.id }] }
    let(:annotation_reception) do
      AnnotationReception.create!(
        annotator_id: annotator.id,
        project_id: project.id,
        job_id: job.id,
        options:,
        hdoc_metadata:
      )
    end

    it 'processes annotations and finishes the job' do
      # Before: check that denotations in the project are empty
      expect(project.denotations.count).to eq(0)

      # Before: check that attributes have already been created
      expect(project.attributes.count).to eq(33)

      annotation_reception.process_annotation!(annotations_collection)

      # After: check that denotations in the project are not empty
      expect(project.denotations.count).to eq(2)

      # After: check that the number of attributes has not increased
      expect(project.attributes.count).to eq(33)
    end

    it 'raises error for invalid annotation' do
      expect {
        annotation_reception.process_annotation!([['not a hash']])
      }.to raise_error(RuntimeError, /Annotation result is not a valid JSON object/)
    end
  end
end