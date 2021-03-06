#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#
module Lti
  class LtiAppsController < ApplicationController
    before_action :require_context
    before_action :require_user, except: [:launch_definitions]

    def index
      if authorized_action(@context, @current_user, :read_as_admin)
        collection = app_collator.bookmarked_collection

        respond_to do |format|
          app_defs = Api.paginate(collection, self, named_context_url(@context, :api_v1_context_app_definitions_url, include_host: true))

          mc_status = setup_master_course_restrictions(app_defs.select{|o| o.is_a?(ContextExternalTool)}, @context)
          format.json {render json: app_collator.app_definitions(app_defs, :master_course_status => mc_status)}
        end
      end
    end

    def launch_definitions
      placements = params['placements'] || []
      if authorized_for_launch_definitions(@context, @current_user, placements)
        # only_visible requires that specific placements are requested.  If a user is not read_admin, and they request only_visible
        # without placements, an empty array will be returned.
        if placements == ['global_navigation']
          # We allow global_navigation to pull all the launch_definitions, even if they are not explicitly visible to user.
          collection = AppLaunchCollator.bookmarked_collection(@context, placements, {current_user: @current_user, session: session, only_visible: false})
        else
          collection = AppLaunchCollator.bookmarked_collection(@context, placements, {current_user: @current_user, session: session, only_visible: true})
        end
        pagination_args = {max_per_page: 100}
        respond_to do |format|
          launch_defs = Api.paginate(
            collection,
            self,
            named_context_url(@context, :api_v1_context_launch_definitions_url, include_host: true),
            pagination_args
          )
          format.json { render :json => AppLaunchCollator.launch_definitions(launch_defs, placements) }
        end
      end
    end


    private

    def lti_tools_1_3
      collection = tool_configs.each_with_object([]) do |tool, memo|
        config = {}
        dk_id = tool.developer_key_id
        config[:config] = tool
        config[:installed_for_context] = active_tools_for_key_context_combos.key?(dk_id)
        config[:installed_tool_id] = active_tools_for_key_context_combos[dk_id]&.first&.last #get the cet id if present
        # TODO: fix the issue where it shows installed at account when installed at course
        config[:installed_at_context_level] = active_tools_for_key_context_combos.dig(dk_id, "#{@context.id}#{@context.class.name}").present?
        memo << config
      end

      respond_to do |format|
        format.json {render json: app_collator.app_definitions(collection)}
      end
    end

    def active_tools_for_key_context_combos
      @active_tools ||= begin
        q = if @context.class.name == 'Course'
              ContextExternalTool.
                active.
                where(developer_key: dev_keys, context_id: @context.id, context_type: @context.class.name).
                or(
                  ContextExternalTool.
                  active.
                  where(developer_key: dev_keys, context_id: @context.account_chain_ids, context_type: 'Account')
                )
            else
              ContextExternalTool.
                active.
                where(
                  developer_key: dev_keys, context_id: [@context.id] + @context.account_chain_ids, context_type: @context.class.name
                )
            end
        q.pluck(:developer_key_id, :context_id, :context_type, :id).each_with_object({}) do |key, memo|
          memo[key.first] ||= {}
          memo[key.first]["#{key.second}#{key.third}"] = key.fourth
        end
      end
    end

    def tool_configs
      @tool_configs ||= dev_keys.map(&:tool_configuration)
    end

    def dev_keys
      @dev_keys ||= begin
        context = @context.is_a?(Account) ? @context : @context.account
        bindings = DeveloperKeyAccountBinding.lti_1_3_tools(context)
        (bindings + Account.site_admin.shard.activate { DeveloperKeyAccountBinding.lti_1_3_tools(Account.site_admin) }).
          map(&:developer_key).
          select(&:usable?)
      end
    end

    def app_collator
      @app_collator ||= AppCollator.new(@context, method(:reregistration_url_builder))
    end

    def reregistration_url_builder(context, tool_proxy_id)
        polymorphic_url([context, :tool_proxy_reregistration], tool_proxy_id: tool_proxy_id)
    end

    def authorized_for_launch_definitions(context, user, placements)
      # This is a special case to allow any user (students especially) to access the
      # launch definitions for global navigation specifically. This is requested in
      # the context of an account, not a course, so a student would normally not
      # have any account-level permissions. So instead, just ensure that the user
      # is associated with the current account (not sure how it could be otherwise?)
      return true if context.is_a?(Account) && \
        placements == ['global_navigation'] && \
        user_in_account?(user, context)

      authorized_action(context, user, :read)
    end

    def user_in_account?(user, account)
      user.associated_accounts.include? account
    end
  end
end
