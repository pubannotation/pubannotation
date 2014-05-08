#!/usr/bin/env ruby
#encoding: UTF-8
Encoding.default_external="UTF-8"
Encoding.default_internal="UTF-8"

require 'json'

class Annotation
  def initialize(json)
    @annotation = JSON.parse json, :symbolize_names => true
  end

  def get_ann
    # index
    text = @annotation[:text]
    denotations = @annotation[:denotations]
    instances = @annotation[:instances]
    relations = @annotation[:relations]
    modifications = @annotation[:modifications]

    denotations = Hash.new;
    denotations.each {|c| denotations[c[:id]] = c} if denotations

    events = Hash.new;
    instances.each {|i| events[i[:id]] = {:tid => i[:object]}} if instances

    relations = Array.new
    wholeof   = Hash.new;
    equivs    = Hash.new;

    if relations

      relations.each do |r|
        if (r[:object][0] == 'E')

          type = r[:type][0...-2]
          unless events[r[:object]][type]
            events[r[:object]][type] = [ r[:subject] ]
          else
            events[r[:object]][type].push(r[:subject])
          end

        elsif (r[:object][0] == 'T')

          case r[:type]
          when 'partOf'

            unless wholeof[r[:subject]]
              wholeof[r[:subject]] = Array.new
            end
            unless wholeof[r[:subject]].include? r[:object]
              wholeof[r[:subject]].push r[:object]
            end

          when 'coreferenceOf'

            r[:type] = 'Coreference'
            relations.push r

          when 'equivalentTo'

            unless equivs[r[:object]]
              equivs[r[:object]] = Array.new
            end
            unless equivs[r[:object]].include? r[:subject]
              equivs[r[:object]].push r[:subject]
            end

          else

            warn "unhandled relation type: [#{r[:type]}]"

          end

        else
            warn "unknown prefix of ID for a relation: [#{r[:type]}]"
        end
      end
    end


    # arguments processing
    events.each_key do |eid|
      events[eid].each_key do |k|
        if events[eid][k].respond_to?(:each)
          unless k == 'theme'
            warn "multiple arguments other than 'theme'" if events[eid][k].length > 1
            events[eid][k] = events[eid][k][0]
          end
        end
      end
    end

    # part-whole control
    events.each_key do |eid|
      if (events[eid]['theme'])
        events[eid]['theme'].map! do |t|
          ws = wholeof[t];
          ws ? ws.length == 1 ? ws[0] + '-' + t : ws.map{|w| w + '-' + t} : t
        end
      else
        warn "no theme error: [#{id} - #{tid}]"
      end

      if (events[eid]['cause'])
        c = events[eid]['cause']
        ws = wholeof[c];
        events[eid]['cause'] = ws ? ws.length == 1 ? ws[0] + '-' + c : ws.map{|w| w + '-' + c} : c
      end
    end

    eids_incomplete = events.keys.select do |eid|
      events[eid]['theme'].count{|a| a.respond_to?(:each)} > 0 || events[eid]['cause'].respond_to?(:each)
    end

    partition_eids_incomplete = Array.new
    eids_incomplete.each do |eid|
      pushed = false
      partition_eids_incomplete.each do |p|
        if events[eid] == events[p[0]]
          p.push(eid) 
          pushed = true
          break
        end
      end

      partition_eids_incomplete.push([eid]) unless pushed
    end

    partition_eids_incomplete.each do |p|
      multies = Array.new
      events[p[0]]['theme'].each_with_index do |t, i|
        multies.push(i) if t.respond_to?(:each)
      end

      multies.push('cause') if events[p[0]]['cause'].respond_to?(:each)

      if (multies.length == 1)
        if multies[0] == 'cause'
          p.each_with_index do |eid, i|
            events[eid]['cause'] = events[eid]['cause'][i]
          end
        else
          p.each_with_index do |eid, i|
            events[eid]['theme'][multies[0]] = events[eid]['theme'][multies[0]][i]
          end
        end
      else
        warn "===== Not yet implemented! ====="
      end
    end

    a1 = ''

    if denotations
      denotations.each do |c|
        if c[:obj] == 'Protein'
          b = c[:denotation][:begin]
          e = c[:denotation][:end]
          a1 += "#{c[:id]}\t#{c[:obj]} #{c[:denotation][:begin]} #{c[:denotation][:end]}\t#{text[b...e]}\n"
        end
      end
    end

    a2 = ''
    equivs.each_key do |k|
      a2 += "*\tEquiv #{k} #{equivs[k].join(' ')}\n"
    end

    if denotations
      denotations.each do |c|
        unless c[:obj] == 'Protein'
          b = c[:denotation][:begin]
          e = c[:denotation][:end]
          a2 += "#{c[:id]}\t#{c[:obj]} #{c[:denotation][:begin]} #{c[:denotation][:end]}\t#{text[b...e]}\n"
        end
      end
    end

    relations.each do |r|
      a2 += "#{r[:id]}\t#{r[:type]} Subject:#{r[:subject]} Object:#{r[:object]}\n"
    end

    events.each_key do |id|
      tid = events[id][:tid]
      a2 += "#{id}" # id
      a2 += "\t#{denotations[tid][:obj]}:#{tid}" # trigger

      if (events[id]['theme'])
        events[id]['theme'].each_with_index do |t, i|
          idx = (i == 0)? '' : (i + 1).to_s
          th, site = t.split('-')
          a2 += " Theme#{idx}:#{th}"
          a2 += " Site#{idx}:#{site}" if site
        end
      end

      if (events[id]['cause'])
        c = events[id]['cause']
        cs, site = c.split('-')
        a2 += " Cause:#{cs}"
        a2 += " CSite:#{site}" if site
      end

      if (events[id]['location'])
        l = events[id]['location']
#        a2 += " Location:#{l}"
        a2 += " ToLoc:#{l}"
      end

      if (events[id]['fromLocation'])
        l = events[id]['fromLocation']
        a2 += " fromLocation:#{l}"
      end

      a2 += "\n"

    end

    if modifications
      modifications.each do |m|
        a2 += "#{m[:id]}\t#{m[:type]} #{m[:object]}\n"
      end
    end

    [text, a1, a2]
  end

end

if __FILE__ == $0

  odir = nil

  ## command line option processing
  require 'optparse'
  optparse = OptionParser.new do |opts|
    opts.banner = "Usage: sen-reid.rb [options]"

    opts.on('-o', '--output directory', 'specifies the output directory.') do |d|
      odir = d.sub(/\/$/, '')
    end
      
    opts.on('-h', '--help', 'displays this screen.') do
      puts opts
      exit
    end
  end

  optparse.parse!
  exit unless odir

  ARGV.each do |fpath|
    abort ("not a json file: #{fpath}") unless fpath.end_with?('.json')
    fname = File.basename(fpath, '.json')
    puts "#{fpath} - under processing."

    annotation = Annotation.new(File.read(fpath))
    text, a1, a2 = annotation.get_ann

    File.open("#{odir}/#{fname}.txt", 'w') {|f| f.write(text)}
    File.open("#{odir}/#{fname}.a1",  'w') {|f| f.write(a1)}
    File.open("#{odir}/#{fname}.a2",  'w') {|f| f.write(a2)}
  end
end
