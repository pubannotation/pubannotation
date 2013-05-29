require 'test_helper'

class spansControllerTest < ActionController::TestCase
  setup do
    @span = spans(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:spans)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create span" do
    assert_difference('Span.count') do
      post :create, span: { begin: @span.begin, category: @span.category, end: @span.end, hid: @span.hid }
    end

    assert_redirected_to span_path(assigns(:span))
  end

  test "should show span" do
    get :show, id: @span
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @span
    assert_response :success
  end

  test "should update span" do
    put :update, id: @span, span: { begin: @span.begin, category: @span.category, end: @span.end, hid: @span.hid }
    assert_redirected_to span_path(assigns(:span))
  end

  test "should destroy span" do
    assert_difference('Span.count', -1) do
      delete :destroy, id: @span
    end

    assert_redirected_to spans_path
  end
end
