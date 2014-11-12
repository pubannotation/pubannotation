#!/usr/bin/env ruby
#encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'rest_client'
require 'xml'

class DocSequencerPubMed
  attr_reader :source_url, :divs

  def initialize (id)
    raise "'#{id}' is not a valid ID of PubMed" unless id =~ /^(PubMed|PMID)?[:-]?([1-9][0-9]*)$/
    docid = $2

    RestClient.get "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pubmed&retmode=xml&id=#{docid}" do |response, request, result|
      case response.code
      when 200
        parser = XML::Parser.string(response, :encoding => XML::Encoding::UTF_8)
        doc = parser.parse

        result   = doc.find_first('/PubmedArticleSet').content.strip
        return nil if result.empty?
        title    = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/ArticleTitle')
        # abstract = doc.find_first('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Abstract/AbstractText')
        abstexts = doc.find('/PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Abstract/AbstractText')

        texts = []
        texts << title.content.strip if title
        abstexts.each do |abstext|
          text = abstext.content.strip
          unless text.empty?
            texts << abstext[:Label] if abstext[:Label]
            texts << text
          end
        end
        body = texts.join("\n")
        puts body

        @source_url = 'http://www.ncbi.nlm.nih.gov/pubmed/' + docid
        @divs = [{:heading => 'TIAB', :body => body}]
      else
        raise "PubMed unreachable."
      end
    end
  end
end

if __FILE__ == $0
  require 'optparse'
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: doc_sequencer_pubmed.rb [option(s)] id"

    opts.on('-h', '--help', 'displays this screen') do
      puts opts
      exit
    end
  end

  optparse.parse!

  normal = 0
  abnormal = 0

  ARGV.each do |id|

    begin
      doc = DocSequencerPubMed.new(id)
    rescue
      warn $!
      exit
    end

    p doc.source_url
    puts '======'
    p doc.divs
  end
end
