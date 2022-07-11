require 'test_helper'

class InstantiateAndSaveAnnotationsCollectionTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
  end

  test "instantiate_and_save_annotations_collection" do
    current = Time.zone.local(2022, 7, 11, 10, 04, 44)
    travel_to current do
      InstantiateAndSaveAnnotationsCollection.call @project, []
    end

    @project.reload
    assert_equal 0, @project.denotations_num
    assert_equal 0, @project.relations_num
    assert_equal 0, @project.modifications_num
    assert_equal current, @project.updated_at
    assert_equal current, @project.annotations_updated_at
  end
end
