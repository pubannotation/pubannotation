#!/usr/bin/env ruby
#encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'wikipedia'

class DocSequencerWikipedia
  attr_reader :source_url, :divs

  def initialize (id)
    page = Wikipedia.find(id)

    raise "'#{id}' is not a valid ID of First Authors" unless id =~ /^(FA)?[:-]?([1-9][0-9]*)$/
    docid = $2

    url = 'http://first.lifesciencedb.jp/archives/' + docid
    html = open(url)
    raise "#{docid} does not exist in First Authors or the server is unreachable." unless html

    @doc = Nokogiri::HTML(html)

    @source_url = url
    @divs = get_divs
  end

  def empty?
    (@doc)? false : true
  end

  def get_divs
    title = get_title
    secs  = get_secs

    if title and secs
      divs = []

      divs << {:heading => 'TIAB', :body => title + "\n" + secs.first[:body]}

      secs.each do |sec|
        stitle = sec[:heading]
        next if stitle == '要 約'

        label  = stitle
        divs << {:heading => label, :body => sec[:body]}
      end

      return divs
    else
      return nil
    end
  end

  def get_title
    titles = @doc.xpath('//div[@id="contentleft"]//h1')
    if titles.length == 1
      title = titles.first.content.strip
    else
      warn "more than one titles."
      return nil
    end
  end

  def get_secs
    secs = []
    sec = {}

    body = @doc.xpath('//div[@id="contentleft"]').first.traverse do |node|
      if node.element?
        if node.name == 'h2'
          secs << sec.dup if sec[:heading]

          if node.content == '文 献'
            sec[:heading] = nil
            sec[:body] = nil
          else
            sec[:heading] = node.content.strip
            sec[:body] = node.content.strip
          end
        elsif sec[:heading] && node.name == 'p'
          sec[:body] += "\n" + node.content.strip
        end
      end
    end

    secs
  end

end

if __FILE__ == $0
  source = 'n'
  output = nil

  require 'optparse'
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: pmcdoc.rb [option(s)] id"

    opts.on('-h', '--help', 'displays this screen') do
      puts opts
      exit
    end
  end

  optparse.parse!

  ARGV.each do |id|
    fadoc = DocSequencerFA.new(id)
    p fadoc.source_url
    puts "-----"
    p fadoc.divs
    puts "-----"
  end

end
