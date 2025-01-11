import { inject as service } from "@ember/service";
import { action, get } from "@ember/object";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { bind } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CategoryRestrictorManager from "../components/modal/category-restrictor-manager";
import DButton from "discourse/components/d-button";

export default class RestrictorManagerButton extends Component {
  @service currentUser;
  @service siteSettings;
  @service modal;

  @action
  showCategoryRestrictorManager()
  {
    this.modal.show(CategoryRestrictorManager, {
      model: {
        category: this.args?.category
      }
    });
  }

  get getLabel()
  {
    if (this.args.location == "category-custom-security") {
      return "discourse_category_restrictor.button_label";
    }
    else {
      return "";
    }
  }
  get showButton()
  {
    // if someone can see this page it's ok anyway
    if (this.args.location == "category-custom-security") {
      return true;
    }
    // show button on category page only for category moderators
    if (this.args.location == "before-create-topic-button") {
      const categoryId = this.args?.category?.id;
      return (categoryId && this.currentUser && this.currentUser.category_moderator_for_ids.includes(categoryId));
    }
    return false;
  }

  <template>
    {{#if this.showButton}}
      <DButton
        @action={{this.showCategoryRestrictorManager}}
        @icon="user-slash"
        @label={{this.getLabel}}
      />
    {{/if}}
  </template>
}
