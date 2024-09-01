# frozen_string_literal: true

module DiscourseCategoryRestrictor::PostGuardianExtension
    def can_create_post_in_topic?(topic)
      return false unless super
      return true unless topic&.category
      return !@user.silenced_categories.include?(topic&.category.id)
    end
  end
