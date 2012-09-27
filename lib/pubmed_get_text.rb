#!/usr/bin/env ruby
# encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'rest_client'
require 'xml'
require 'htmlentities'

class PubMed
  def initialize
    @resource = RestClient::Resource.new "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
  end

  def get_text(pmid)
    @resource.get :params => {:db => :pubmed, :retmode => :xml, :id => pmid} do |response, request, result|
      case response.code
      when 200
        parser = XML::Parser.string(response, :encoding => XML::Encoding::UTF_8)
        doc = parser.parse
        title    = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/ArticleTitle').content
        abstract = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Abstract/AbstractText').content
        title + "\n" + abstract + "\n"
      end
    end
  end

  def get_pmdoc(pmid)
    tiab = get_text(pmid)
    if tiab and !tiab.empty?
      doc = Doc.new
      doc.body = tiab
      doc.source = 'http://www.ncbi.nlm.nih.gov/pubmed/' + pmid
      doc.sourcedb = 'PubMed'
      doc.sourceid = pmid
      doc.serial = 0
      doc.section = 'TIAB'
      return doc
    else
      return nil
    end
  end

  def get_text_clean(pmid)
    text = get_text(pmid)

    # escape non-ascii characters
    coder = HTMLEntities.new
    text = coder.encode(text, :named)

    # restore back
    text.gsub!('&apos;', "'")

    # change escape characters
    text.gsub!(/&([a-zA-Z]{1,10});/, '==\1==')

    text
  end

end

if __FILE__ == $0

  pubmed = PubMed.new

  ARGF.each do |l|
    l.chomp!
    r = pubmed.get_text(l)
    print r
  end
end
