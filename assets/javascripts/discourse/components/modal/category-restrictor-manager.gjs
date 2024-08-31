import { action, get } from "@ember/object";
import { on } from "@ember/modifier";
import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import UserChooser from "select-kit/components/user-chooser";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";

export default class CategoryRestrictorManager extends Component {
  @service currentUser;
  @tracked users = [];
  @tracked usernames = [];

  init() {
    super.init(...arguments);
    this.loadUsers();
  }

  async loadUsers() {
    try {
      const response = await ajax(`/category-restrictor/restrict/${this.model.category.id}/users`);
      this.users = this.processUserData(response);
    } catch (error) {
      console.error("Failed to load users:", error);
    }
  }

  processUserData(response) {
    return response.silenced_users.map(user => ({
      ...user,
      status: 'silenced',
    }));
  }

  get modalTitle() {
    return I18n.t("discourse_category_restrictor.modal_title", { name: this.model.category.name} );
  }

  get addButtonDisabled() {
    return this.usernames.length == 0;
  }

  statusLabel(status) {
    return I18n.t(`discourse_category_restrictor.statuses.${status}`);
  }

  @action
  mutTargetUsername(selectedUsernames) {
    this.usernames = [selectedUsernames[0]] || [];
  }

  @action
  async addSilencedUser() {
    var username = this.usernames[0] || "";
    if (!username.trim()) {
      alert('Please enter a username.');
      return;
    }

    try {
      const userResponse = await ajax(`/u/${username}.json`);
      const userId = userResponse.user.id;
      this.usernames = [];
      await ajax(`/category-restrictor/restrict/${this.model.category.id}/${userId}/silence`, {
        method: 'POST',
        data: { restriction_type: 'silence' }
      });
      this.loadUsers(); // Reload users to update the table
    } catch (error) {
      console.error("Failed to add silenced user:", error);
      alert('Failed to add silenced user. User not found or request failed.');
    }
  }

  @action
  async removeUser(userId) {
    try {
      await ajax(`/category-restrictor/restrict/${this.model.category.id}/${userId}/silence`, {
        method: 'DELETE'
      });
      this.loadUsers(); // Reload users to update the table
    } catch (error) {
      alert('Failed to remove user.');
    }
  }

  <template>
    <DModal @title={{this.modalTitle}} @closeModal={{@closeModal}} class="category-restrictor-manager">
      <:body>
        <div class="silenced-users-container">
          <!-- Input and Button to Add a Silenced User -->
          <div class="add-silenced-user">
            <UserChooser
              @value={{this.usernames}}
              @onChange={{this.mutTargetUsername}}
              @options={{hash
                excludeCurrentUser=true
                allowEmails=false
                maximum=1
              }}
            />
            <DButton
              class="btn btn-primary"
              @action={{this.addSilencedUser}}
              @label="discourse_category_restrictor.silence_label"
              @disabled={{this.addButtonDisabled}}>
            </DButton>
          </div>

          <table class="silenced-users-table">
            <thead>
              <tr>
                <th colspan="2">{{i18n "discourse_category_restrictor.table_headings.username"}}</th>
                <th>{{i18n "discourse_category_restrictor.table_headings.status"}}</th>
                <th>{{i18n "discourse_category_restrictor.table_headings.actions"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.users as |user|}}
                <tr>
                  <td class="avatar"><img src={{user.avatar_template}} class="user-avatar" /></td>
                  <td class="username">{{user.username}}</td>
                  <td class="status">{{this.statusLabel user.status}}</td>
                  <td class="button">
                    <DButton
                      class="btn btn-danger"
                      @icon="trash-alt"
                      @label="discourse_category_restrictor.remove_label"
                      @action={{fn this.removeUser user.id}}
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </div>
      </:body>
      <:footer>
        <DButton
          @action={{@closeModal}}
          @label="discourse_category_restrictor.ok_label"
        />
      </:footer>
    </DModal>
  </template>
}
