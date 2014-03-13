#!/usr/bin/env ruby
#encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'rest_client'
require 'nokogiri'
require 'open-uri'

class FADoc
  attr_reader :doc, :message

  def initialize(id, filename=nil)
    if id
      html = open("http://first.lifesciencedb.jp/archives/#{id}")
      @message = "The First Author document, #{id}, does not exist." unless html
    elsif filename
      html = File.read(filename)
      @message = "The file, #{filename}, does not exist." unless html
    end

    if html
      @doc = Nokogiri::HTML(html)
    else
      @doc = nil
    end
  end

  def empty?
    (@doc)? false : true
  end

  def get_divs
    title = get_title
    secs  = get_secs

    if title and secs
      divs = Array.new

      divs << ['TIAB', title + "\n" + secs.first[:content]]

      secs.each do |sec|
        stitle = sec[:title]
        next if stitle == '要 約'

        label  = stitle
        divs << [label, sec[:content]]
      end

      return divs
    else
      return nil
    end
  end

  def get_title
    titles = @doc.xpath('//div[@id="contentleft"]//h1')
    if titles.length == 1
      title = titles.first.content
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
          secs << sec.dup if sec[:title]

          if node.content == '文 献'
            sec[:title] = nil
            sec[:content] = nil
          else
            sec[:title] = node.content
            sec[:content] = node.content  
          end
        elsif sec[:title] && node.name == 'p'
          sec[:content] += "\n" + node.content 
        end
      end
    end

    secs
  end


  def check_sec (sec)
    title = ''
    sec.each_element do |e|
      case e.name
      when 'title'
        title = e.content.strip
        return false unless check_title(e)
      when 'label'
      when 'p'
        return false unless check_p(e)
      when 'sec'
        return false unless check_sec(e)
      when 'fig', 'table-wrap'
        return false unless check_float(e)
      else
        warn "unexpected element in sec (#{title}): #{e.name}"
        return false
      end
    end
    return true
  end


  def check_subsec (sec)
    sec.each_element do |e|
      case e.name
      when 'title'
        return false unless check_title(e)
      when 'label'
      when 'p'
        return false unless check_p(e)
      when 'fig', 'table-wrap'
        return false unless check_float(e)
      else
        warn "unexpected element in subsec: #{e.name}"
        return false
      end
    end
    return true
  end


  def check_abstract (node)
    node.each_element do |e|
      case e.name
      when 'title'
        return false unless check_title(e)
      when 'p'
        return false unless check_p(e)
      when 'sec'
        return false unless check_subsec(e)
      else
        warn "unexpected element in abstract: #{e.name}"
        return false
      end
    end
    return true
  end


  def check_title(node)
    return true

    node.each_element do |e|
      case e.name
      when 'italic', 'bold', 'sup', 'sub', 'underline'
      else
        warn "unexpected element in title: #{e.name}"
        return false
      end
    end
    return true
  end


  def check_p(node)
    node.each_element do |e|
      case e.name
      when 'italic', 'bold', 'sup', 'sub', 'underline', 'sc'
      when 'xref', 'ext-link', 'named-content'
      when 'fig', 'table-wrap'
      else
        return false
      end
    end
    return true
  end


  def check_float(node)
    labels   = node.find('./label')
    captions = node.find('./caption')

    if labels.length == 1 and captions.length == 1
      label   = labels.first
      caption = captions.first

      caption.each_element do |e|
        case e.name
        when 'title'
          return false unless check_title(e)
        when 'p'
          return false unless check_p(e)
        else
          warn "unexpected element in caption: #{e.name}"
          return false
        end
      end
      return true
    else
      return false
    end
  end


  def get_text (node)
    text = ''
    node.each do |e|
      if e.node_type_name == 'element' and e.name == 'sec'
        text += get_text(e)
      else
        text += e.content.strip.gsub(/\n/, ' ').gsub(/ +/, ' ')
      end
      text += "\n" if e.node_type_name == 'element' and (e.name == 'sec' or e.name == 'title' or e.name == 'p')
    end
    text.strip
  end

end

if __FILE__ == $0
  source = 'n'
  output = nil

  require 'optparse'
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: pmcdoc.rb [options]"

    opts.on('-f', '--fileread', 'tells it to read the documents from files.') do
      source = 'f'
    end

    opts.on('-h', '--save_to_html', 'tells it to save the documents to html files.') do
      output = 'html'
    end

    opts.on('-h', '--help', 'displays this screen') do
      puts opts
      exit
    end
  end

  optparse.parse!

  ARGV.each do |id|
    fadoc = FADoc.new(id)
    p fadoc.doc.class
    p fadoc.get_title
    puts "-----"
    fadoc.get_divs.each do |d|
      p d
    end

  exit


    if source == "n"
      pmcdoc = PMCDoc.new(p)
      id = p
    else
      pmcdoc = PMCDoc.new(nil, p)
      p =~ /([0-9]+)/
      id = $1
    end

    unless pmcdoc.doc
      puts pmcdoc.message
      exit
    end

    if divs = pmcdoc.get_divs
      normal += 1
      puts "#{id}\t:good"
      if output == 'html'
        divs.each_with_index do |d, i|

          doc = HTML::Document.new()
          doc.root = HTML::Node.new('clipSet')
          root = doc.root
          root << clip = HTML::Node.new('clip')
          d[1].each_line do |l|
            clip << p = HTML::Node.new('p')
            p << l.chomp
          end
          outfilename = "PMC-#{id}-%02d-#{d[0].gsub(/ /, '_')}.html" % i
          doc.save(outfilename, :encoding => HTML::Encoding::UTF_8)
        end
      end
    else
      abnormal += 1
      puts "#{id}\t:bad"
    end

  end

  puts
  puts "Good  : #{normal}"
  puts "Bad   : #{abnormal}"
  puts "Total : #{normal+abnormal}"
end
