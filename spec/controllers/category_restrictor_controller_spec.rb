# plugins/discourse-category-restrictor/spec/controllers/category_restrictor_controller_spec.rb

require 'rails_helper'

RSpec.describe ::DiscourseCategoryRestrictor::CategoryRestrictorController, type: :controller do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:category) { Fabricate(:category) }
  fab!(:user) { Fabricate(:user) }
  fab!(:silenced_user) { Fabricate(:user, custom_fields: { 'silenced_categories' => "|#{category.id}|" }) }
  fab!(:banned_user) { Fabricate(:user, custom_fields: { 'banned_categories' => "|#{category.id}|" }) }

  before do
    SiteSetting.category_restrictor_enabled = true
  end

  describe '#index' do
    it 'lists all silenced and banned users for a category' do
      #sign_in(admin)
      get :index, params: { category_id: category.id }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json['silenced_users'].map { |u| u['id'] }).to include(silenced_user.id)
      expect(json['banned_users'].map { |u| u['id'] }).to include(banned_user.id)
    end

    it 'raises an error if the user does not have permission' do
        log_in(user)
      expect {
        get :index, params: { category_id: category.id }
      }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe '#create_or_update' do
    it 'silences a user in a category' do
      post :create_or_update, params: { category_id: category.id, user_id: user.id, restriction_type: 'silence' }

      expect(response.status).to eq(200)
      expect(user.reload.custom_fields['silenced_categories']).to include("|#{category.id}|")
      expect(user.reload.custom_fields['banned_categories']).not_to include("|#{category.id}|")
    end

    it 'bans a user in a category' do
      post :create_or_update, params: { category_id: category.id, user_id: user.id, restriction_type: 'ban' }

      expect(response.status).to eq(200)
      expect(user.reload.custom_fields['banned_categories']).to include("|#{category.id}|")
      expect(user.reload.custom_fields['silenced_categories']).not_to include("|#{category.id}|")
    end

    it 'raises an error for invalid restriction types' do
      expect {
        post :create_or_update, params: { category_id: category.id, user_id: user.id, restriction_type: 'invalid' }
      }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe '#destroy' do
    before do
      user.custom_fields['silenced_categories'] = "|#{category.id}|"
      user.save_custom_fields
    end

    it 'removes a silenced restriction from a user' do
      delete :destroy, params: { category_id: category.id, user_id: user.id, restriction_type: 'silence' }

      expect(response.status).to eq(200)
      expect(user.reload.custom_fields['silenced_categories']).not_to include("|#{category.id}|")
    end

    it 'removes a banned restriction from a user' do
      user.custom_fields['banned_categories'] = "|#{category.id}|"
      user.save_custom_fields

      delete :destroy, params: { category_id: category.id, user_id: user.id, restriction_type: 'ban' }

      expect(response.status).to eq(200)
      expect(user.reload.custom_fields['banned_categories']).not_to include("|#{category.id}|")
    end

    it 'raises an error for invalid restriction types' do
      expect {
        delete :destroy, params: { category_id: category.id, user_id: user.id, restriction_type: 'invalid' }
      }.to raise_error(Discourse::InvalidParameters)
    end
  end
end
