import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action, get } from "@ember/object";
import { on } from "@ember/modifier";
import Component from "@ember/component";
import { tracked } from "@glimmer/tracking";
import ItsATrap from "@discourse/itsatrap";
import { formattedReminderTime } from "discourse/lib/bookmark";
import {
  timeShortcuts,
  TIME_SHORTCUT_TYPES,
} from "discourse/lib/time-shortcut";
import I18n from "discourse-i18n";
import { inject as service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { fn } from "@ember/helper";

export default class CategoryRestrictorManager extends Component {
  @service currentUser;

  @service store;

  @tracked users = [];
  @tracked username = '';

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

  @action
  updateUsername(event) {
    this.username = event.target.value;
  }

  @action
  async addSilencedUser() {
    if (!this.username.trim()) {
      alert('Please enter a username.');
      return;
    }

    try {
      const userResponse = await ajax(`/u/${this.username}.json`);
      const userId = userResponse.user.id;

      await ajax(`/category-restrictor/restrict/${this.model.category.id}/${userId}/silence`, {
        method: 'POST',
        data: { restriction_type: 'silence' }
      });
      alert(`${user.username} has been silenced.`);
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
      alert('User has been removed.');
      this.loadUsers(); // Reload users to update the table
    } catch (error) {
      console.error("Failed to remove user:", error);
      alert('Failed to remove user.');
    }
  }

  <template>
    <DModal @title={{this.modalTitle}} @closeModal={{@closeModal}} class="category-restrictor-manager">
  <:body>
  <div class="silenced-users-container">
  <!-- Input and Button to Add a Silenced User -->
  <div class="add-silenced-user">
    <input
      type="text"
      placeholder="Enter username"
      {{on "input" this.updateUsername}}
    />
    <button class="btn btn-primary" {{on "click" this.addSilencedUser}}>Add Silenced User</button>
  </div>

  <!-- Table of Silenced Users -->
  <table class="silenced-users-table">
    <thead>
      <tr>
        <th>Avatar</th>
        <th>Username</th>
        <th>Status</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      {{#each this.users as |user|}}
        <tr>
          <td><img src={{user.avatar_template}} class="user-avatar" /></td>
          <td>{{user.username}}</td>
          <td>{{user.status}}</td>
          <td>
            <button class="btn btn-danger" {{on "click" (fn this.removeUser user.id)}}>Remove</button>
          </td>
        </tr>
      {{/each}}
    </tbody>
  </table>
</div>
  </:body>
  <:footer>
  </:footer>
</DModal>
  </template>

}
