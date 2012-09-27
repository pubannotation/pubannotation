require 'test_helper'

class AnnsetsControllerTest < ActionController::TestCase
  setup do
    @annset = annsets(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:annsets)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create annset" do
    assert_difference('Annset.count') do
      post :create, annset: { annotator: @annset.annotator, description: @annset.description, name: @annset.name }
    end

    assert_redirected_to annset_path(assigns(:annset))
  end

  test "should show annset" do
    get :show, id: @annset
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @annset
    assert_response :success
  end

  test "should update annset" do
    put :update, id: @annset, annset: { annotator: @annset.annotator, description: @annset.description, name: @annset.name }
    assert_redirected_to annset_path(assigns(:annset))
  end

  test "should destroy annset" do
    assert_difference('Annset.count', -1) do
      delete :destroy, id: @annset
    end

    assert_redirected_to annsets_path
  end
end
