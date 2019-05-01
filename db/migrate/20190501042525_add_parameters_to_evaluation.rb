class AddParametersToEvaluation < ActiveRecord::Migration
  def change
    add_column :evaluations, :soft_match_characters, :integer
    add_column :evaluations, :soft_match_words, :integer
    add_column :evaluations, :denotations_type_match, :text
    add_column :evaluations, :relations_type_match, :text
  end
end
