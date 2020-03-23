require 'rubygems/package'
require 'zlib'
require 'fileutils'

class CreateAnnotationsTgzJob < Struct.new(:project, :options)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, project.docs.count)
		@job.update_attribute(:num_dones, 0)

		blind_p = project.accessibility == 3 ? true : false
		dic = []

		FileUtils.mkdir_p(project.downloads_system_path) unless Dir.exist?(project.downloads_system_path)
		Zlib::GzipWriter.open(project.annotations_tgz_system_path, Zlib::BEST_COMPRESSION) do |gz|
			Gem::Package::TarWriter.new(gz) do |tar|
				project.docs.each_with_index do |doc, i|
					begin
						doc.set_ascii_body if options[:encoding] == 'ascii'
						filename = doc.filename

						file = doc.body
						tar.add_file_simple(project.name + '/txt/' + filename + ".txt", 0644, file.bytesize){|t| t.write(file)}
						if project.denotations_num > 0
							if blind_p
								file = doc.to_hash.to_json
								tar.add_file_simple(project.name + '/json/' + filename + ".json", 0644, file.bytesize){|t| t.write(file)}
							else
								annotations = doc.hannotations(project)
								file = annotations.to_json
								tar.add_file_simple(project.name + '/json/' + filename + ".json", 0644, file.bytesize){|t| t.write(file)}
								file = Annotation.hash_to_tsv(annotations)
								tar.add_file_simple(project.name + '/tsv/' + filename + ".tsv", 0644, file.bytesize){|t| t.write(file)}
								dic += Annotation.hash_to_dic_array(annotations)
							end
						end
					rescue => e
						@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: e.message})
					end
					@job.update_attribute(:num_dones, i + 1)
				end

				unless dic.empty?
					dic.uniq!
					file = Annotation.dic_array_to_tsv(dic)
					tar.add_file_simple(project.name + '/dic/' + project.name + ".dic", 0644, file.bytesize){|t| t.write(file)}
				end
			end
		end
	end

end
