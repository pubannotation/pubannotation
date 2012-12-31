#!/usr/bin/env ruby
#encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'rest_client'
require 'xml'

class PMCDoc
  attr_reader :doc, :message

  def initialize(pmcid, filename=nil)
    if pmcid
      RestClient.get "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pmc&retmode=xml&id=#{pmcid}" do |response, request, result|
        case response.code
        when 200
          if response.index("PMC#{pmcid} not found")
            @doc = nil
            @message = "#{pmcid} is a non-existence article ID."
          else
            parser = XML::Parser.string(response, :encoding => XML::Encoding::UTF_8)
            @doc = parser.parse
          end
        else
          @doc = nil
          @message = "PubMed Central unreachable."
        end
      end
    elsif filename
      file = File.read(filename)
      if file
        parser = XML::Parser.string(file, :encoding => XML::Encoding::UTF_8)
        @doc = parser.parse
      else
        @doc = nil
        @message = "File not found"
      end
    end
  end


  def empty?
    (@doc)? false : true
  end


  def get_divs
    title    = get_title
    abstract = get_abstract
    secs     = get_secs
    psec     = (secs and secs[0].is_a?(Array))? secs.shift : nil 

    if title and abstract and secs

      # extract captions
      caps = Array.new

      if psec
        psec.each do |p|
          figs = p.find('.//fig')
          tbls = p.find('.//table-wrap')

          figs.each do |f|
            label   = f.find_first('./label').content.strip
            caption = f.find_first('./caption')
            caps << ['Caption-' + label, get_text(caption)]
          end

          tbls.each do |t|
            label   = t.find_first('./label').content.strip
            caption = t.find_first('./caption')
            caps << ['Caption-' + label, get_text(caption)]
          end

          figs.each {|f| f.remove!}
          tbls.each {|t| t.remove!}
        end
      end


      secs.each do |sec|
        figs = sec.find('.//fig')
        tbls = sec.find('.//table-wrap')

        figs.each do |f|
          label   = f.find_first('./label').content.strip
          caption = f.find_first('./caption')
          caps << ['Caption-' + label, get_text(caption)]
        end

        tbls.each do |t|
          label   = t.find_first('./label').content.strip
          caption = t.find_first('./caption')
          caps << ['Caption-' + label, get_text(caption)]
        end

        figs.each {|f| f.remove!}
        tbls.each {|t| t.remove!}
      end

      divs = Array.new

      divs << ['TIAB', get_text(title) + "\n" + get_text(abstract)]

      if psec
        text = ''
        psec.each {|p| text += get_text(p)}
        divs << ["INTRODUCTION", text]
      end

      secs.each do |sec|
        stitle  = sec.find_first('./title')
        label   = stitle.content.strip
        stitle.remove!

        ps      = sec.find('./p')
        subsecs = sec.find('./sec')

        # remove dummy section
        if subsecs.length == 1
          subsubsecs = subsecs[0].find('./sec')
          subsecs = subsubsecs
        end

        if subsecs.length > 0 and ps.length > 0
          text = ''
          ps.each do |p|
            text += get_text(p)
          end
          divs << [label, text]
          subsecs.each do |subsec|
            divs << [label, get_text(subsec)]
          end          
        elsif subsecs.length > 0
          subsecs.each do |subsec|
            divs << [label, get_text(subsec)]
          end
        elsif ps.length > 0
          divs << [label, get_text(sec)]
        else
          warn "strange section."
          return nil
        end
      end

      return divs + caps
    else
      return nil
    end
  end


  def get_title
    titles = @doc.find('/pmc-articleset/article/front/article-meta/title-group/article-title')
    if titles.length == 1
      title = titles.first
      return (check_title(title))? title : nil
    else
      warn "more than one titles."
      return nil
    end
  end


  def get_abstract
    abstracts = @doc.find('/pmc-articleset/article/front/article-meta/abstract')

    if abstracts.length == 1
      abstract = abstracts.first
    elsif abstracts.length > 1
      abstracts.each do |a|
        unless a['abstract-type']
          abstract = a
          break
        end
      end
    else
      warn "no abstract."
    end

    if abstract and check_abstract(abstract)
      return abstract
    else
      return nil
    end
  end


  def get_secs
    body = @doc.find_first('/pmc-articleset/article/body')

    if body
      secs = Array.new
      psec = Array.new

      body.each_element do |e|
        case e.name
        when 'p'
          if secs.empty?
            psec << e
          else
            warn "<p> element between <sec> elements"
            return nil
          end
        when 'sec'
          secs << psec if secs.empty? and !psec.empty?

          title = e.find_first('title').content.strip.downcase
          case title
          # filtering by title
          when /contributions$/, /supplementary/, /abbreviations/, 'competing interests', 'supporting information', 'additional information', 'funding'
          else
            if check_sec(e)
              secs << e
            else
              return nil
            end
          end
        when 'supplementary-material'
        else
          warn "element out of sec: #{e.name}"
          return nil
        end
      end

      if secs.empty?
        return nil
      else
        return secs
      end
    else
      return nil
    end
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

    opts.on('-x', '--save_to_xml', 'tells it to save the documents to xml files.') do
      output = 'xml'
    end

    opts.on('-h', '--help', 'displays this screen') do
      puts opts
      exit
    end
  end

  optparse.parse!

  normal = 0
  abnormal = 0

  ARGV.each do |p|

    if source == "n"
      pmcdoc = PMCDoc.new(p)
      pmcid = p
    else
      pmcdoc = PMCDoc.new(nil, p)
      p =~ /([0-9]+)/
      pmcid = $1
    end

    unless pmcdoc.doc
      puts pmcdoc.message
      exit
    end

    if divs = pmcdoc.get_divs
      normal += 1
      puts "#{pmcid}\t:good"
      if output == 'xml'
        divs.each_with_index do |d, i|

          doc = XML::Document.new()
          doc.root = XML::Node.new('clipSet')
          root = doc.root
          root << clip = XML::Node.new('clip')
          d[1].each_line do |l|
            clip << p = XML::Node.new('p')
            p << l.chomp
          end
          outfilename = "PMC-#{pmcid}-%02d-#{d[0].gsub(/ /, '_')}.xml" % i
          doc.save(outfilename, :encoding => XML::Encoding::UTF_8)
        end
      end
    else
      abnormal += 1
      puts "#{pmcid}\t:bad"
    end

  end

  puts
  puts "Good  : #{normal}"
  puts "Bad   : #{abnormal}"
  puts "Total : #{normal+abnormal}"
end
