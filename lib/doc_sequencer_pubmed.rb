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
        title    = doc.find_first('/PubmedArticleSet//ArticleTitle')
        vtitle   = doc.find_first('/PubmedArticleSet//VernacularTitle')
        abstractTexts = doc.find('/PubmedArticleSet//Abstract/AbstractText')
        abstract = abstractTexts
                    .collect{|t| t['Label'].nil? ? t.content.strip : t['Label'] + ': ' + t.content.strip}
                    .join("\n")
        abstractText = doc.find_first('/PubmedArticleSet//OtherAbstract/AbstractText')
        abstract += abstractText.content.strip unless abstractText.nil?

        body  = ''
        body += title.content.strip if title
        body += "\n" + vtitle.content.strip if vtitle
        body += "\n" + abstract.strip if abstract

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
