# frozen_string_literal: true

module DenotationBagger
  extend ActiveSupport::Concern

  def bag_denotations(denotations, relations)
    raise unless denotations.respond_to?('each')
    raise unless relations.respond_to?('each')
    raise unless denotations.first.is_a?(Hash) if denotations.first
    raise unless relations.first.is_a?(Hash) if relations.first

    # To merge spans of denotations that are lexically chained.
    merged_denotations = {}

    relations.each do |ra|
      if ra[:pred] == '_lexicallyChainedTo'
        # To see if either subject or object is already merged to another.
        ra[:subj] = merged_denotations[ra[:subj]] if merged_denotations.has_key? ra[:subj]
        ra[:obj] = merged_denotations[ra[:obj]] if merged_denotations.has_key? ra[:obj]

        # To find the indexes of the subject and object
        idx_from = denotations.find_index{|d| d[:id] == ra[:subj]}
        idx_to   = denotations.find_index{|d| d[:id] == ra[:obj]}
        from = denotations[idx_from]
        to   = denotations[idx_to]

        from[:span] = [from[:span]] unless from[:span].respond_to?('push')
        to[:span]   = [to[:span]]   unless to[:span].respond_to?('push')

        # To merge the two spans (in the reverse order)
        from[:span] = to[:span] + from[:span]

        # To delete the object denotation
        denotations.delete_at(idx_to)

        # To update the merged denotations
        merged_denotations[ra[:obj]] = ra[:subj]
      end
    end

    relations.delete_if{|ra| ra[:pred] == '_lexicallyChainedTo'}

    return denotations, relations
  end
end
