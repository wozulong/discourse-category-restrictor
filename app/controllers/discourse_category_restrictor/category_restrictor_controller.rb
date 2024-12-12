module ::DiscourseCategoryRestrictor
    class CategoryRestrictorController < ::ApplicationController
      before_action :ensure_logged_in
      before_action :find_user_and_category, except: [:index]

      def index
        category = Category.find(params[:category_id])
        raise Discourse::InvalidAccess unless current_user.staff? || current_user.guardian.is_category_group_moderator?(category)

        silenced_users = find_users_with_restriction('silenced_categories', category.id)
        banned_users = find_users_with_restriction('banned_categories', category.id)

        render json: {
          silenced_users: silenced_users.map { |u| { id: u.id, username: u.username, avatar_template: u.avatar_template.sub("{size}", "25") } },
          banned_users: banned_users.map { |u| { id: u.id, username: u.username, avatar_template: u.avatar_template.sub("{size}", "25") } }
        }
      end

      def create_or_update
        restriction_type = params.require(:restriction_type)
        raise Discourse::InvalidParameters.new(:restriction_type) unless %w[silence ban].include?(restriction_type)

        # add to the key
        custom_field_key = restriction_type == 'silence' ? 'silenced_categories' : 'banned_categories'
        category_ids = get_category_ids(@user, custom_field_key)
        unless category_ids.include?(@category.id)
          category_ids << @category.id
          save_category_ids(@user, custom_field_key, category_ids)
        end

        # remove from the other key
        custom_field_key = restriction_type == 'silence' ? 'banned_categories' : 'silenced_categories'
        category_ids = get_category_ids(@user, custom_field_key)
        if category_ids.include?(@category.id)
          category_ids -= [@category.id]
          save_category_ids(@user, custom_field_key, category_ids)
        end

        render json: success_json
      end

      def destroy
        restriction_type = params.require(:restriction_type)
        raise Discourse::InvalidParameters.new(:restriction_type) unless %w[silence ban].include?(restriction_type)

        custom_field_key = restriction_type == 'silence' ? 'silenced_categories' : 'banned_categories'

        category_ids = get_category_ids(@user, custom_field_key)
        if category_ids.delete(@category.id)
          save_category_ids(@user, custom_field_key, category_ids)
        end

        render json: success_json
      end

      private

      def find_user_and_category
        @category = Category.find(params[:category_id])
        @user = User.find(params[:user_id])
        raise Discourse::InvalidParameters.new(:category_id) unless @category
        raise Discourse::InvalidAccess unless current_user.staff? || current_user.guardian.is_category_group_moderator?(@category)
      end

      def get_category_ids(user, custom_field_key)
        # we must remove [0] because split produces that bogus value, and that's because we start and end the list of values with "|"
        # and we do that to simplify the LIKE below
        (user.custom_fields[custom_field_key] || "").split("|").map(&:to_i) - [0]
      end

      def save_category_ids(user, custom_field_key, category_ids)
        user.custom_fields[custom_field_key] = "|" + category_ids.uniq.join("|") + "|"
        user.save_custom_fields
      end

      def find_users_with_restriction(custom_field_key, category_id)
        UserCustomField.where(name: custom_field_key)
                       .where('value LIKE ?', "%|#{category_id}|%")
                       .map(&:user)
      end
    end
  end
