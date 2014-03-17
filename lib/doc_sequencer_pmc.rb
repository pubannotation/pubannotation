#!/usr/bin/env ruby
#encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'rest_client'
require 'xml'

class DocSequencerPMC
  attr_reader :source_url, :divs

  def initialize (id)
    raise "'#{id}' is not a valid ID of PMC" unless id =~ /^(PMC)?[:-]?([1-9][0-9]*)$/
    docid = $2

    RestClient.get "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=pmc&retmode=xml&id=#{docid}" do |response, request, result|
      case response.code
      when 200
        raise "#{docid} does not exist in PMC." if response.index("PMC#{docid} not found")
          
        parser = XML::Parser.string(response, :encoding => XML::Encoding::UTF_8)
        @doc = parser.parse
        @source_url = 'http://www.ncbi.nlm.nih.gov/pmc/' + docid
        @divs = get_divs
      else
        raise "PMC unreachable."
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
          subsecs = subsubsecs
        end

        if subsecs.length > 0 and ps.length > 0
          text = ''
          ps.each do |p|
            text += get_text(p)
          end
          divs << {:heading => label, :body => text}
          subsecs.each do |subsec|
            divs << {:heading => label, :body => get_text(subsec)}
          end          
        elsif subsecs.length > 0
          subsecs.each do |subsec|
            divs << {:heading => label, :body => get_text(subsec)}
          end
        elsif ps.length > 0
          divs << {:heading => label, :body => get_text(sec)}
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
  require 'optparse'
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: doc_sequencer_pmc.rb [option(s)] id"

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
      doc = DocSequencerPMC.new(id)
    rescue
      warn $!
      exit
    end

    p doc.source_url
    puts '======'
    p doc.divs
  end
end
