import EmberObject from "@ember/object";
import { bind, scheduleOnce } from "@ember/runloop";
import $ from "jquery";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscourseURL from "discourse/lib/url";
import { CREATE_TOPIC } from "discourse/models/composer";
import {
  default as discourseComputed,
  observes,
  on,
} from "discourse-common/utils/decorators";
import I18n from "I18n";

export default {
  name: "category-restrictor",
  initialize(container) {
    withPluginApi("1.4.0", (api) => {
      api.modifyClass("controller:discovery.list", {
        pluginId: "category-restrictor",
        get createTopicDisabled() {
          if (this._super(...arguments)) {
            return true;
          }
          // if not disabled, check if we should disable because of silencing
          return this.model.category && this.currentUser?.silenced_categories?.includes(this.model.category.id);
        },
      });

    });
  }
}

