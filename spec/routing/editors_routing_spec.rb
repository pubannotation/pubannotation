require "spec_helper"

describe EditorsController do
  describe "routing" do

    it "routes to #index" do
      get("/editors").should route_to("editors#index")
    end

    it "routes to #new" do
      get("/editors/new").should route_to("editors#new")
    end

    it "routes to #show" do
      get("/editors/1").should route_to("editors#show", :id => "1")
    end

    it "routes to #edit" do
      get("/editors/1/edit").should route_to("editors#edit", :id => "1")
    end

    it "routes to #create" do
      post("/editors").should route_to("editors#create")
    end

    it "routes to #update" do
      put("/editors/1").should route_to("editors#update", :id => "1")
    end

    it "routes to #destroy" do
      delete("/editors/1").should route_to("editors#destroy", :id => "1")
    end

  end
end
