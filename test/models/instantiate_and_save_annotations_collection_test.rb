require 'test_helper'

class InstantiateAndSaveAnnotationsCollectionTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
  end

  test "instantiate_and_save_annotations_collection" do
    InstantiateAndSaveAnnotationsCollection.call @project, []
  end
end
