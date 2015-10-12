require 'spec_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

describe AnnotatorsController do

  # This should return the minimal set of attributes required to create a valid
  # Annotator. As you add validations to Annotator, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) { { "abbrev" => "MyString" } }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # AnnotatorsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET index" do
    it "assigns all annotators as @annotators" do
      annotator = Annotator.create! valid_attributes
      get :index, {}, valid_session
      assigns(:annotators).should eq([annotator])
    end
  end

  describe "GET show" do
    it "assigns the requested annotator as @annotator" do
      annotator = Annotator.create! valid_attributes
      get :show, {:id => annotator.to_param}, valid_session
      assigns(:annotator).should eq(annotator)
    end
  end

  describe "GET new" do
    it "assigns a new annotator as @annotator" do
      get :new, {}, valid_session
      assigns(:annotator).should be_a_new(Annotator)
    end
  end

  describe "GET edit" do
    it "assigns the requested annotator as @annotator" do
      annotator = Annotator.create! valid_attributes
      get :edit, {:id => annotator.to_param}, valid_session
      assigns(:annotator).should eq(annotator)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Annotator" do
        expect {
          post :create, {:annotator => valid_attributes}, valid_session
        }.to change(Annotator, :count).by(1)
      end

      it "assigns a newly created annotator as @annotator" do
        post :create, {:annotator => valid_attributes}, valid_session
        assigns(:annotator).should be_a(Annotator)
        assigns(:annotator).should be_persisted
      end

      it "redirects to the created annotator" do
        post :create, {:annotator => valid_attributes}, valid_session
        response.should redirect_to(Annotator.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved annotator as @annotator" do
        # Trigger the behavior that occurs when invalid params are submitted
        Annotator.any_instance.stub(:save).and_return(false)
        post :create, {:annotator => { "abbrev" => "invalid value" }}, valid_session
        assigns(:annotator).should be_a_new(Annotator)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Annotator.any_instance.stub(:save).and_return(false)
        post :create, {:annotator => { "abbrev" => "invalid value" }}, valid_session
        response.should render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      it "updates the requested annotator" do
        annotator = Annotator.create! valid_attributes
        # Assuming there are no other annotators in the database, this
        # specifies that the Annotator created on the previous line
        # receives the :update_attributes message with whatever params are
        # submitted in the request.
        Annotator.any_instance.should_receive(:update_attributes).with({ "abbrev" => "MyString" })
        put :update, {:id => annotator.to_param, :annotator => { "abbrev" => "MyString" }}, valid_session
      end

      it "assigns the requested annotator as @annotator" do
        annotator = Annotator.create! valid_attributes
        put :update, {:id => annotator.to_param, :annotator => valid_attributes}, valid_session
        assigns(:annotator).should eq(annotator)
      end

      it "redirects to the annotator" do
        annotator = Annotator.create! valid_attributes
        put :update, {:id => annotator.to_param, :annotator => valid_attributes}, valid_session
        response.should redirect_to(annotator)
      end
    end

    describe "with invalid params" do
      it "assigns the annotator as @annotator" do
        annotator = Annotator.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Annotator.any_instance.stub(:save).and_return(false)
        put :update, {:id => annotator.to_param, :annotator => { "abbrev" => "invalid value" }}, valid_session
        assigns(:annotator).should eq(annotator)
      end

      it "re-renders the 'edit' template" do
        annotator = Annotator.create! valid_attributes
        # Trigger the behavior that occurs when invalid params are submitted
        Annotator.any_instance.stub(:save).and_return(false)
        put :update, {:id => annotator.to_param, :annotator => { "abbrev" => "invalid value" }}, valid_session
        response.should render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested annotator" do
      annotator = Annotator.create! valid_attributes
      expect {
        delete :destroy, {:id => annotator.to_param}, valid_session
      }.to change(Annotator, :count).by(-1)
    end

    it "redirects to the annotators list" do
      annotator = Annotator.create! valid_attributes
      delete :destroy, {:id => annotator.to_param}, valid_session
      response.should redirect_to(annotators_url)
    end
  end

end
