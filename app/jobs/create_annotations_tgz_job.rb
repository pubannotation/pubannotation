require "rubygems/package"

class CreateAnnotationsTgzJob < ApplicationJob
	queue_as :low_priority

	def perform(project, options)
		if @job
			prepare_progress_record(project.docs.count)
		end

		blind_p = project.accessibility == 3 ? true : false
		textae_config = project.get_textae_config
		dic = []
		dic_bag = []

		has_discontinuous_span = project.has_discontinuous_span?

		tmp_file_path = "#{Rails.root}/tmp/#{project.annotations_tgz_filename}"
		Zlib::GzipWriter.open(tmp_file_path, Zlib::BEST_COMPRESSION) do |gz|
			Gem::Package::TarWriter.new(gz) do |tar|
				project.docs.each_with_index do |doc, i|
					begin
						doc.set_ascii_body if options[:encoding] == 'ascii'
						filename = doc.filename

						file = doc.body
						tar.add_file_simple(project.name + '/texts/' + filename + ".txt", 0644, file.bytesize){|t| t.write(file)}
						if project.denotations_num > 0
							if blind_p
								file = doc.to_hash.to_json
								tar.add_file_simple(project.name + '/annotations/json/' + filename + ".json", 0644, file.bytesize){|t| t.write(file)}
							else
								annotations = doc.hannotations(project)
								file = annotations.to_json
								tar.add_file_simple(project.name + '/annotations/json/' + filename + ".json", 0644, file.bytesize){|t| t.write(file)}
								file = Annotation.hash_to_tsv(annotations, textae_config)
								tar.add_file_simple(project.name + '/annotations/tsv/' + filename + ".tsv", 0644, file.bytesize){|t| t.write(file)}
								dic += Annotation.hash_to_dic_array(annotations)
								if has_discontinuous_span
									annotations = doc.hannotations(project, nil, nil, {discontinuous_span: :bag})
									file = annotations.to_json
									tar.add_file_simple(project.name + '/annotations/bag_json/' + filename + ".json", 0644, file.bytesize){|t| t.write(file)}
									file = Annotation.hash_to_tsv(annotations, textae_config)
									tar.add_file_simple(project.name + '/annotations/bag_tsv/' + filename + ".tsv", 0644, file.bytesize){|t| t.write(file)}
									dic_bag += Annotation.hash_to_dic_array(annotations)
								end
							end
						end
					rescue => e
						@job.add_message sourcedb: doc.sourcedb,
														 sourceid: doc.sourceid,
														 body: e.message
					end
					if @job
						@job.update_attribute(:num_dones, i + 1)
						check_suspend_flag
					end
				end

				unless dic.empty?
					dic.uniq!
					file = Annotation.dic_array_to_tsv(dic)
					tar.add_file_simple(project.name + '/dictionary/' + project.name + "_dictionary.tsv", 0644, file.bytesize){|t| t.write(file)}
				end

				unless dic_bag.empty?
					dic_bag.uniq!
					file = Annotation.dic_array_to_tsv(dic_bag)
					tar.add_file_simple(project.name + '/dictionary/' + project.name + "_bag_dictionary.tsv", 0644, file.bytesize){|t| t.write(file)}
				end

				file = if dic_bag.empty?
					<<~README
						Directory structure

						/texts/             contains the text files
						/annotations/       contains the annotations
						/annotations/json/  contains annotations in JSON
						/annotations/tsv/   contains annotations in TSV (tab-separated-values) format
						/dictionary/        contains the dictionary (the collection of string and label mappings)
					README
				else
					<<~README
						Directory structure

						/texts/                 contains the text files
						/annotations/           contains the annotations
						/annotations/json/      contains annotations in JSON
						/annotations/tsv/       contains annotations in TSV (tab-separated-values)
						/annotations/bag_json/  contains annotations in JSON, discontinuous spans are expressed in the bag model
						/annotations/bag_tsv/   contains annotations in TSV, discontinuous spans are expressed in the bag model
						/dictionary/            contains the dictionary (the collection of string and label mappings)
					README
				end

				tar.add_file_simple(project.name + '/README.txt', 0644, file.bytesize){|t| t.write(file)}
			end
		end

		FileUtils.mkdir_p(project.downloads_system_path) unless Dir.exist?(project.downloads_system_path)
		FileUtils.mv tmp_file_path, project.annotations_tgz_system_path
	end

	def job_name
		'Create a downloadable archive'
	end
end
