# frozen_string_literal: true

module DiscourseCategoryRestrictor::TopicGuardianExtension
  def can_create_topic_on_category?(category)
    return false unless super

    # allow for category to be a number as well
    category_id = Category === category ? category.id : category
    return !@user.silenced_categories.include?(category_id.to_i)
  end
end
