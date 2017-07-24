require 'rubygems/package'
require 'zlib'
require 'fileutils'

class CreateAnnotationsTgzJob < Struct.new(:project, :options)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, project.docs.count)
		@job.update_attribute(:num_dones, 0)

    FileUtils.mkdir_p(project.downloads_system_path) unless Dir.exist?(project.downloads_system_path)
    Zlib::GzipWriter.open(project.annotations_tgz_system_path, Zlib::BEST_COMPRESSION) do |gz|
      Gem::Package::TarWriter.new(gz) do |tar|
				project.docs.each_with_index do |doc, i|
					begin
						doc.set_ascii_body if options[:encoding] == 'ascii'
						annotations = doc.hannotations(project)
	          title = get_doc_info(annotations).sub(/\.$/, '').gsub(' ', '_')
	          path  = project.name + '/' + title + ".json"
	          stuff = annotations.to_json
	          tar.add_file_simple(path, 0644, stuff.length){|t| t.write(stuff)}
	        rescue => e
		 	      doc_description  = [doc.sourcedb, doc.sourceid, doc.serial].compact.join('-')
						@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: e.message})
					end
					@job.update_attribute(:num_dones, i + 1)
        end
      end
    end
	end

  def get_doc_info (annotations)
    sourcedb = annotations[:sourcedb]
    sourceid = annotations[:sourceid]
    divid    = annotations[:divid]
    if divid.present?
      doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, divid.to_i)
      section   = doc.section.to_s if doc.present?
    end
    docinfo   = (divid == nil)? "#{sourcedb}-#{sourceid}" : "#{sourcedb}-#{sourceid}-#{divid}-#{section}"
  end
end
