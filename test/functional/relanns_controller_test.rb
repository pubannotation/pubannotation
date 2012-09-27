require 'test_helper'

class RelannsControllerTest < ActionController::TestCase
  setup do
    @relann = relanns(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:relanns)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create relann" do
    assert_difference('Relann.count') do
      post :create, relann: { hid: @relann.hid, relation: @relann.relation }
    end

    assert_redirected_to relann_path(assigns(:relann))
  end

  test "should show relann" do
    get :show, id: @relann
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @relann
    assert_response :success
  end

  test "should update relann" do
    put :update, id: @relann, relann: { hid: @relann.hid, relation: @relann.relation }
    assert_redirected_to relann_path(assigns(:relann))
  end

  test "should destroy relann" do
    assert_difference('Relann.count', -1) do
      delete :destroy, id: @relann
    end

    assert_redirected_to relanns_path
  end
end
