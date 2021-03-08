require_dependency 'avo/application_controller'

module Avo
  class ActionsController < ApplicationController
    before_action :set_resource_name
    before_action :set_resource
    before_action :set_action, only: [:show, :handle]

    def show; end

    def handle
      resource_ids = action_params[:fields][:resource_ids].split(',').map(&:to_i)
      models = @resource.model_class.find resource_ids

      fields = action_params[:fields].select do |key, value|
        key != 'resource_ids'
      end

      performed_action = @action.handle_action(request, models, fields)

      respond performed_action.response
    end

    private
      def action_params
        params.permit(:resource_name, :action_id, fields: {})
      end

      def set_action
        action_class = params[:action_id].gsub('avo_actions_', '').classify
        action_name = "Avo::Actions::#{action_class}"

        if params[:id].present?
          model = @resource.model_class.find params[:id]
        end

        @action = action_name.safe_constantize.new
        @action.hydrate(model: model, resource: resource, user: _current_user)
        @action.boot_fields request
      end

      def respond(response)
        response[:type] ||= :reload
        response[:message_type] ||= :notice
        response[:message] ||= I18n.t('avo.action_ran_successfully')

        if response[:type] == :download
          return send_data response[:path], filename: response[:filename]
        end

        respond_to do |format|
          format.html do
            if response[:type] == :redirect
              path = response[:path]

              if path.respond_to? :call
                path = instance_eval &path
              end

              redirect_to path, "#{response[:message_type]}": response[:message]
            elsif response[:type] == :reload
              redirect_back fallback_location: resources_path(@resource.model_class), "#{response[:message_type]}": response[:message]
            end
          end
        end
      end
  end
end
