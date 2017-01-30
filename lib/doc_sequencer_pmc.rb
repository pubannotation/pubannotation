#!/usr/bin/env ruby
#encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'rest_client'
require 'xml'

class DocSequencerPMC
  attr_reader :source_url, :xml, :divs

  def initialize (id)
    raise ArgumentError, "id is nil." if id.nil?

    id = id.strip
    raise ArgumentError, "'#{id}' is not a valid ID of PMC" unless id.match(/^(PMC)?[:-]?([1-9][0-9]*)$/)

    id = id.sub(/^PMC[:-]?/, '')

    RestClient.get "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pmc&retmode=xml&id=#{id}" do |response, request, result|
      case response.code
      when 200
        @xml = response
        raise ArgumentError, "#{id} not found in PMC." if @xml.index("PMC#{id} not found")
        raise ArgumentError, "#{id} not found in PMC." if @xml.index("PMCID is not available")
        puts @xml
        parser = XML::Parser.string(@xml, :encoding => XML::Encoding::UTF_8)
        @doc = parser.parse
        @source_url = 'http://www.ncbi.nlm.nih.gov/pmc/' + id
        @divs = get_divs
      else
        raise "PMC unreachable."
      end
    end
  end

  private

  def get_divs
    title    = get_title
    abstract = get_abstract
    secs     = get_secs
    psec     = (secs and secs[0].is_a?(Array))? secs.shift : nil 

    raise 'could not find the title' if title.nil?
    raise 'could not find the abstract' if abstract.nil?
    raise 'could not find a section' if secs.nil? || secs.empty?

    # extract captions
    caps = []

    if psec
      psec.each do |p|
        figs = p.find('.//fig')
        tbls = p.find('.//table-wrap')

        figs.each do |f|
          label   = f.find_first('./label').content.strip
          caption = f.find_first('./caption')
          caps << {:heading => 'Caption-' + label, :body => get_text(caption)}
        end

        tbls.each do |t|
          label   = t.find_first('./label').content.strip
          caption = t.find_first('./caption')
          caps << {:heading => 'Caption-' + label, :body => get_text(caption)}
        end

        figs.each {|f| f.remove!}
        tbls.each {|t| t.remove!}
      end
    end

    # extract figures and tables
    secs.each do |sec|
      figs = sec.find('.//fig')
      tbls = sec.find('.//table-wrap')

      figs.each do |f|
        label   = f.find_first('./label').content.strip
        caption = f.find_first('./caption')
        caps << {:heading => 'Caption-' + label, :body => get_text(caption)}
      end

      tbls.each do |t|
        label   = t.find_first('./label').content.strip
        caption = t.find_first('./caption')
        caps << {:heading => 'Caption-' + label, :body => get_text(caption)}
      end

      figs.each {|f| f.remove!}
      tbls.each {|t| t.remove!}
    end

    divs = []

    divs << {:heading =>'TIAB', :body => get_text(title) + "\n" + get_text(abstract)}

    if psec
      text = ''
      psec.each {|p| text += get_text(p)}
      divs << {:heading => "INTRODUCTION", :body => text}
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
        subsecs = subsubsecs if subsubsecs.length > 0
      end

      if subsecs.length == 0
        divs << {:heading => label, :body => get_text(sec)}
      else
        if ps.length > 0
          text = ps.collect{|p| get_text(p)}.join
          divs << {:heading => label, :body => text}
        end

        subsecs.each do |subsec|
          divs << {:heading => label, :body => get_text(subsec)}
        end
      end
    end

    divs.each{|d| d[:body].strip!}
    caps.each{|d| d[:body].strip!}

    return divs + caps
  end


  def get_title
    titles = @doc.find('/pmc-articleset/article/front/article-meta/title-group/article-title')
    if titles.length == 1
      title = titles.first
      return (check_title(title))? title : nil
    else
      raise "more than one titles."
    end
  end


  def get_abstract
    abstracts = @doc.find('/pmc-articleset/article/front/article-meta/abstract')
    raise "no abstract" if abstracts.nil? || abstracts.empty?

    if abstracts.length == 1
      abstract = abstracts.first
    else
      abstracts.each do |a|
        unless a['abstract-type']
          abstract = a
          break
        end
      end
    end

    return abstract if abstract && check_abstract(abstract)
    raise "something wrong in getting the abstract."
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
            raise "a <p> element between <sec> elements"
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
              raise "a unexpected structure of <sec>"
            end
          end
        when 'supplementary-material'
        else
          raise "an element out of sec: #{e.name}"
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
      when 'disp-formula'
      when 'graphic'
      when 'list'
      when 'p'
        return false unless check_p(e)
      when 'sec'
        return false unless check_sec(e)
      when 'fig', 'table-wrap'
        return false unless check_float(e)
      else
        raise "a unexpected element in sec (#{title}): #{e.name}"
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
        raise "a unexpected element in subsec: #{e.name}"
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
        raise "a unexpected element in abstract: #{e.name}"
        return false
      end
    end
    return true
  end


  def check_title(node)
    node.each_element do |e|
      case e.name
      when 'italic', 'bold', 'sup', 'sub', 'underline'
      when 'xref', 'named-content'
      else
        raise "a unexpected element in title: #{e.name}"
        return false
      end
    end
    return true
  end


  def check_p(node)
    node.each_element do |e|
      case e.name
      when 'italic', 'bold', 'sup', 'sub', 'underline', 'sc'
      when 'xref', 'ext-link', 'uri', 'named-content'
      when 'fig', 'table-wrap'
      when 'statement' # TODO: check what it is
      when 'inline-graphic', 'disp-formula', 'inline-formula' # TODO: check if it can be ignored.
      else
        raise "a unexpected element in p: #{e.name}"
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
          raise "a unexpected element in caption: #{e.name}"
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
      if e.node_type_name == 'element' && (e.name == 'sec' || e.name == 'list' || e.name == 'list-item')
        text += get_text(e)
      else
        text += e.content.strip.gsub(/\n/, ' ').gsub(/ +/, ' ')
      end
      text += "\n" if e.node_type_name == 'element' && (e.name == 'sec' || e.name == 'title' || e.name == 'p')
    end
    text
  end

end

if __FILE__ == $0
  xmlout = false

  require 'optparse'
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: doc_sequencer_pmc.rb [option(s)] id"

    opts.on('-x', '--xml', 'prints the XML source') do
      xmlout = true
    end

    opts.on('-h', '--help', 'displays this screen') do
      puts opts
      exit
    end
  end

  optparse.parse!

  normal = 0
  abnormal = 0

  ARGV.each do |id|
    warn "processing #{id}"

    begin
      doc = DocSequencerPMC.new(id)
      if xmlout
        puts doc.xml
      else
        p doc.divs
      end
    rescue
      warn $!
      exit
    end
    warn "done----------"
  end
end
