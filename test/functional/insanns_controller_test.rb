require 'test_helper'

class InsannsControllerTest < ActionController::TestCase
  setup do
    @insann = insanns(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:insanns)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create insann" do
    assert_difference('Insann.count') do
      post :create, insann: { hid: @insann.hid }
    end

    assert_redirected_to insann_path(assigns(:insann))
  end

  test "should show insann" do
    get :show, id: @insann
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @insann
    assert_response :success
  end

  test "should update insann" do
    put :update, id: @insann, insann: { hid: @insann.hid }
    assert_redirected_to insann_path(assigns(:insann))
  end

  test "should destroy insann" do
    assert_difference('Insann.count', -1) do
      delete :destroy, id: @insann
    end

    assert_redirected_to insanns_path
  end
end
