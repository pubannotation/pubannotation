class MigratePmcToDivs < ActiveRecord::Migration
  def up
    if Doc.count > 0
      Doc.where(sourcedb: 'PMC').order('sourceid ASC').group_by(&:sourceid).each do |sourceid, docs|
        if docs.size > 1
          begin_pos = 0
          base_doc = docs.detect{|doc| doc.serial == 0}
          docs.sort{|a, b| a.serial <=> b.serial }.each do |doc|
            # concatnate body
            additional_body = doc.serial == 0 ? "" : "#{ doc.body.chomp }\n"
            base_doc.update_attribute(:body, "#{ base_doc.body.chomp }\n#{ additional_body }")

            # create div
            body_length = doc.body.length
            end_pos = base_doc.body.length
            if doc.serial != 0
              begin_pos = Div.last.end
            end
            base_doc.divs.create(begin: begin_pos, end: end_pos, section: doc.section, serial: doc.serial)
            body_for_base_doc = doc.body.chomp + "\n"

            # update denotation and project if docs is not the base_doc
            # denotation
            if doc != base_doc 
              if doc.denotations.present?
                doc.denotations.each do |denotation|
                  Doc.increment_counter(:denotations_count, base_doc.id) if denotation.update_attribute(:doc_id, base_doc.id)
                end
              end

              # projects
              doc.reload
              doc.destroy
            end
          end
        end
      end
    end
  end

  def down
    raise "You can't rollback this migration !"
  end
end
