require 'test_helper'

class ModannsControllerTest < ActionController::TestCase
  setup do
    @modann = modanns(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:modanns)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create modann" do
    assert_difference('Modann.count') do
      post :create, modann: { hid: @modann.hid, modtype: @modann.modtype }
    end

    assert_redirected_to modann_path(assigns(:modann))
  end

  test "should show modann" do
    get :show, id: @modann
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @modann
    assert_response :success
  end

  test "should update modann" do
    put :update, id: @modann, modann: { hid: @modann.hid, modtype: @modann.modtype }
    assert_redirected_to modann_path(assigns(:modann))
  end

  test "should destroy modann" do
    assert_difference('Modann.count', -1) do
      delete :destroy, id: @modann
    end

    assert_redirected_to modanns_path
  end
end
