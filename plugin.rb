# name: discourse-category-restrictor
# about: Allows staff and category moderators to silence users on a per-category basis
# version: 0.1
# authors: Communiteq

enabled_site_setting :category_restrictor_enabled

register_asset "stylesheets/common.scss"

require_relative 'lib/discourse_category_restrictor/engine'

register_svg_icon("fas fa-user-slash")

after_initialize do
  require_relative "app/controllers/discourse_category_restrictor/category_restrictor_controller"
  require_relative "lib/discourse_category_restrictor/topic_guardian_extension"
  require_relative "lib/discourse_category_restrictor/post_guardian_extension"

  add_to_class(:user, :silenced_categories) do
    (custom_fields["silenced_categories"] || "").split('|').map(&:to_i) - [0]
  end

  add_to_serializer(:current_user, :silenced_categories) do
    object.silenced_categories
  end

  # category moderation permissions are only serialized to topics so we must add this
  add_to_serializer(:current_user, :category_moderator_for_ids) do
    Category.where(reviewable_by_group_id: object.group_ids).pluck(:id)
  end

  require_dependency "guardian/topic_guardian"
  require_dependency "guardian/post_guardian"

  reloadable_patch do |plugin|
    # prevent people moving their topic after creation
    TopicGuardian.prepend(DiscourseCategoryRestrictor::TopicGuardianExtension)

    # remove reply button from topics
    PostGuardian.prepend(DiscourseCategoryRestrictor::PostGuardianExtension)
  end

  # catch before topic creation and give a nice error instead of 422
  NewPostManager.add_handler do |manager|
    next unless manager.args[:category]
    category_id = manager.args[:category].to_i
    if manager.user.silenced_categories.include?(category_id)
      result = NewPostResult.new(:created_post, false)
      result.errors.add(:base, I18n.t('discourse_category_restrictor.posting_not_allowed'))
      next result
    else
      next
    end
  end
end

