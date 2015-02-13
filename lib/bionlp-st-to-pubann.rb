#!/usr/bin/env ruby
#encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

module Annotation
  def Annotation.loadFromBioNLPST (txt, a1, a2)
    a1_anns = a1.split(/\n/).collect {|l| l.split(/\t/)[0..1]}
    a2_anns = a2.split(/\n/).collect {|l| l.split(/\t/)[0..1]}

    denotations = Array.new
    relations = Array.new
    modifications = Array.new

    a1_anns.each do |id, ann|
      c, b, e = ann.split(/ /)
      denotations << {:id=> id, :span => {:begin => b, :end => e}, :obj => c}
    end

    rid = 0
    spans = {}

    ## 1st round
    a2_anns.each do |id, ann|

      if id =~ /^T/
        c, b, e = ann.split(/ /)
        if ((c == 'Protein') or (c == 'Entity')) 
          denotations << {:id=> id, :span => {:begin => b, :end => e}, :obj => c}
        end
        spans[id] = {:begin => b, :end => e};
      end

      if id =~ /^R/
        t, s, o = ann.split(/ /)
        s = s.split(/:/)[1]
        o = o.split(/:/)[1]
        t = 'coreferenceOf' if t == 'Coreference'
        relations << {:id=> id, :pred => t, :subj => s, :obj => o}

        rid = id[1..-1].to_i + 1
      end

    end

    partofrel = []

    ## 2nd round
    a2_anns.each do |id, ann|

      if id =~ /^\*/
        arg = ann.split(/ /)
        o  = arg[1]
        ss = arg[2..-1]
        ss.each do |s|
          relations << {:id=> "R#{rid+=1}", :pred => 'equivalentTo', :subj => s, :obj => o}
        end
      end

      if id =~ /^E/
        arg = ann.split(/ /)

        ## instantiation of the event
        r, o = arg.shift.split(/:/)
        denotations << {:id => id, :span => spans[o], :obj => r}

        theme = Array.new
        cause = nil
        site = Array.new
        csite = nil
        toloc = nil
        atloc = nil
        fromloc = nil

        arg.each do |a|
          r, o = a.split(/:/)
          case r
          when 'Theme'
            theme[0] = o
          when /Theme([1-9])/
            i = $1.to_i - 1 
            theme[i] = o
          when 'Site'
            site[0] = o
          when /Site([1-9])/
            i = $1.to_i - 1
            site[i] = o
          when 'CSite'
            csite = o
          when 'Cause'
            cause = o
          when 'ToLoc'
            toloc = o
          when 'AtLoc'
            atloc = o
          when 'FromLoc'
            fromloc = o
          else
            warn "unknown argument: #{r}"
          end
        end

        theme.each_with_index do |t, i|
          if site[i]
            relations << {:id => "R#{rid+=1}", :pred => 'themeOf', :subj => site[i], :obj => id}
            unless (partofrel.include?("#{site[i]}-#{theme[i]}"))
              relations << {:id => "R#{rid+=1}", :pred => 'partOf',  :subj => site[i], :obj => theme[i]}
              partofrel.push("#{site[i]}-#{theme[i]}")
            end
          else
            relations << {:id => "R#{rid+=1}", :pred => 'themeOf', :subj => theme[i], :obj => id}
          end
        end

        if cause
          if csite
            relations << {:id => "R#{rid+=1}", :pred => 'causeOf', :subj => csite, :obj => id}
            unless (partofrel.include?("#{csite}-#{cause}"))
              relations << {:id => "R#{rid+=1}", :pred => 'partOf',  :subj => csite, :obj => cause}
              partofrel.push("#{csite}-#{cause}")
            end
          else
            relations << {:id => "R#{rid+=1}", :pred => 'causeOf', :subj => cause, :obj => id}
          end
        end

        if toloc
          relations << {:id => "R#{rid+=1}", :pred => 'locationOf', :subj => toloc, :obj => id}
        end

        if atloc
          relations << {:id => "R#{rid+=1}", :pred => 'locationOf', :subj => atloc, :obj => id}
        end

        if fromloc
          relations << {:id => "R#{rid+=1}", :pred => 'fromLocationOf', :subj => fromloc, :obj => id}
        end

      end

      if id =~ /^M/
        modtype, modobj = ann.split(/ /)
        modifications << {:id => id, :pred => modtype, :obj => modobj}
      end

    end

    {:text => txt, :denotations => denotations, :relations => relations, :modifications => modifications}
  end

end


if __FILE__ == $0
  require 'uri'
  require 'rest_client'
  require 'json'

  hosturl = nil;
  odir = nil;

  ## config file processing
  require 'parseconfig'
  config   = ParseConfig.new('./bionlp-st-to-pubann.cfg')
  hosturl  = config['hostURL']
  username = config['username']
  password = config['password']
  annset   = config['annotationSet']


  ## command line option processing
  require 'optparse'
  optparse = OptionParser.new do|opts|
    opts.banner = "Usage: bionlp-st-to-pubann-json.rb [options]"

    opts.on('-l', '--location URL', 'specifies the URL of the host.') do |u|
      hosturl = u
    end

    opts.on('-o', '--output directory', 'specifies the output directory.') do |d|
      odir = d
    end

    opts.on('-u', '--user name', 'specifies the user name.') do |n|
      username = n
    end

    opts.on('-p', '--password', 'specifies the user password.') do |p|
      password = p
    end

    opts.on('-s', '--annotation set', 'specifies the annotation set.') do |s|
      annset = s
    end

    opts.on('-h', '--help', 'displays this screen') do
      puts opts
      exit
    end
  end

  optparse.parse!

  if (!odir && hosturl)
    puts "host URL: #{hosturl}"
    puts "annotation set: #{annset}"
    pubann_resource = RestClient::Resource.new(hosturl, {:user => username, :password => password, :headers => {:content_type => :json, :accept => :json}})
    # pubann_resource = RestClient::Resource.new(hosturl, :headers => {:content_type => :json, :accept => :json})
  end

  last_docid = ''
  div_num = 0
  ARGV.each do |ff|
    ## filename checking : needs to be configured.
    fpath = ff.sub(/\.(txt|a1|a2)$/, '')
    fname = fpath.split(/\//).last
    prefix, docid, divid, section = fname.split(/[-.]/)
    next unless (((prefix == 'PMID') || (prefix == 'PMC')) && (docid =~ /^[0-9]+$/))

    if (docid != last_docid) then div_num = 0 else div_num += 1 end
    divid = "%02d" % div_num

    ## read files
    txt = File.read(fpath + '.txt')
    a1  = File.read(fpath + '.a1')
    a2  = File.read(fpath + '.a2')

    ## parsing
    annotations = Annotation.loadFromBioNLPST(txt, a1, a2)

    if (odir)

      unless File.exists?(odir)
        Dir.mkdir(odir)
        puts "Output directory, #{odir}, created."
      end

      outfilename = fname + '.json'
      puts outfilename
      File.open(odir + '/' + outfilename, 'w') {|f| f.write(annotations.to_json)}

    elsif (hosturl)
      post_path = case prefix
                    when 'PMID' then "/projects/#{annset}/docs/sourcedb/pubmed/sourceid/#{docid}/annotations.json"
                    when 'PMC'  then "/projects/#{annset}/docs/sourcedb/PMC/sourceid/#{docid}/divs/#{divid}/annotations.json"
                  end
      puts "post path: #{post_path}"
      pubann_resource[post_path].post({:annotations => annotations}.to_json) do |response, request, result|
        case response.code
          when 200 .. 299 then puts 'post succeeded'
          else puts "post failed: #{response.code}"
        end
      end
    end

    last_docid = docid
  end
end
