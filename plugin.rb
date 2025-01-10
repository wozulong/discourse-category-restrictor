# name: discourse-category-restrictor
# about: Allows staff and category moderators to silence users on a per-category basis
# version: 1.2
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
  add_to_class(:user, :category_moderator_for_ids) do
    return [] unless SiteSetting.enable_category_group_moderation?

    return @category_moderator_for_ids if defined?(@category_moderator_for_ids)
    @category_moderator_for_ids = CategoryModerationGroup
      .joins("INNER JOIN group_users ON group_users.group_id = category_moderation_groups.group_id")
      .where(group_users: { user_id: id })
      .distinct
      .pluck(:category_id)
  end

  add_to_serializer(:current_user, :category_moderator_for_ids) do
    object.category_moderator_for_ids
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
    if manager.user&.silenced_categories&.include?(category_id)
      result = NewPostResult.new(:created_post, false)
      result.errors.add(:base, I18n.t('discourse_category_restrictor.posting_not_allowed'))
      next result
    else
      next
    end
  end
end

