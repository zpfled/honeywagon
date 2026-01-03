require 'rails_helper'

RSpec.describe "Users::RegistrationsController", type: :request do
  describe "GET /users/sign_up" do
    it "renders the sign-up form" do
      get new_user_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign up")
    end
  end

  describe "POST /users" do
    it "creates a user and company on success" do
      params = {
        user: {
          email: "newuser@example.com",
          password: "Password123",
          password_confirmation: "Password123",
          company_name: "NewCo"
        }
      }

      expect {
        post user_registration_path, params: params
      }.to change { User.count }.by(1).and change { Company.count }.by(1)

      expect(response).to redirect_to(authenticated_root_path)
    end

    it "re-renders the form on failure" do
      params = {
        user: {
          email: "",
          password: "short",
          password_confirmation: "mismatch",
          company_name: ""
        }
      }

      expect {
        post user_registration_path, params: params
      }.not_to change { User.count }

      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:ok)
      expect(response.body).to include("error").or include("Sign up")
    end
  end
end
