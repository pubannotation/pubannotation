require 'test_helper'

class CatannsControllerTest < ActionController::TestCase
  setup do
    @catann = catanns(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:catanns)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create catann" do
    assert_difference('Catann.count') do
      post :create, catann: { begin: @catann.begin, category: @catann.category, end: @catann.end, hid: @catann.hid }
    end

    assert_redirected_to catann_path(assigns(:catann))
  end

  test "should show catann" do
    get :show, id: @catann
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @catann
    assert_response :success
  end

  test "should update catann" do
    put :update, id: @catann, catann: { begin: @catann.begin, category: @catann.category, end: @catann.end, hid: @catann.hid }
    assert_redirected_to catann_path(assigns(:catann))
  end

  test "should destroy catann" do
    assert_difference('Catann.count', -1) do
      delete :destroy, id: @catann
    end

    assert_redirected_to catanns_path
  end
end
