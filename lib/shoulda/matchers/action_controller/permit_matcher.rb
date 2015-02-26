require 'delegate'

begin
  require 'strong_parameters'
rescue LoadError
end

require 'active_support/hash_with_indifferent_access'

module Shoulda
  module Matchers
    module ActionController
      # The `permit` matcher tests that an action in your controller receives a
      # whitelist of parameters using Rails' Strong Parameters feature
      # (specifically that `permit` was called with the correct arguments).
      #
      # Here's an example:
      #
      #     class UsersController < ApplicationController
      #       def create
      #         user = User.create(user_params)
      #         # ...
      #       end
      #
      #       private
      #
      #       def user_params
      #         params.require(:user).permit(
      #           :first_name,
      #           :last_name,
      #           :email,
      #           :password
      #         )
      #       end
      #     end
      #
      #     # RSpec
      #     describe UsersController do
      #       it do
      #         should permit(:first_name, :last_name, :email, :password).
      #           for(:create)
      #       end
      #     end
      #
      #     # Test::Unit
      #     class UsersControllerTest < ActionController::TestCase
      #       should permit(:first_name, :last_name, :email, :password).
      #         for(:create)
      #     end
      #
      # If your action requires query parameters in order to work, then you'll
      # need to supply them:
      #
      #     class UsersController < ApplicationController
      #       def update
      #         user = User.find(params[:id])
      #
      #         if user.update_attributes(user_params)
      #           # ...
      #         else
      #           # ...
      #         end
      #       end
      #
      #       private
      #
      #       def user_params
      #         params.require(:user).permit(
      #           :first_name,
      #           :last_name,
      #           :email,
      #           :password
      #         )
      #       end
      #     end
      #
      #     # RSpec
      #     describe UsersController do
      #       before do
      #         create(:user, id: 1)
      #       end
      #
      #       it do
      #         should permit(:first_name, :last_name, :email, :password).
      #           for(:update, params: { id: 1 })
      #       end
      #     end
      #
      #     # Test::Unit
      #     class UsersControllerTest < ActionController::TestCase
      #       setup do
      #         create(:user, id: 1)
      #       end
      #
      #       should permit(:first_name, :last_name, :email, :password).
      #         for(:update, params: { id: 1 })
      #     end
      #
      # Finally, if you have an action that isn't one of the seven resourceful
      # actions, then you'll need to provide the HTTP verb that it responds to:
      #
      #     Rails.application.routes.draw do
      #       resources :users do
      #         member do
      #           put :toggle
      #         end
      #       end
      #     end
      #
      #     class UsersController < ApplicationController
      #       def toggle
      #         user = User.find(params[:id])
      #
      #         if user.update_attributes(user_params)
      #           # ...
      #         else
      #           # ...
      #         end
      #       end
      #
      #       private
      #
      #       def user_params
      #         params.require(:user).permit(:activated)
      #       end
      #     end
      #
      #     # RSpec
      #     describe UsersController do
      #       before do
      #         create(:user, id: 1)
      #       end
      #
      #       it do
      #         should permit(:activated).for(:toggle,
      #           params: { id: 1 },
      #           verb: :put
      #         )
      #       end
      #     end
      #
      #     # Test::Unit
      #     class UsersControllerTest < ActionController::TestCase
      #       setup do
      #         create(:user, id: 1)
      #       end
      #
      #       should permit(:activated).for(:toggle,
      #         params: { id: 1 },
      #         verb: :put
      #       )
      #     end
      #
      # @return [PermitMatcher]
      #
      def permit(*params)
        PermitMatcher.new(params).in_context(self)
      end

      # @private
      class PermitMatcher
        attr_writer :stubbed_params

        def initialize(expected_permitted_params)
          @expected_permitted_params = expected_permitted_params
          @action = nil
          @verb = nil
          @request_params = {}
          @slice = nil

          @double_collections_by_param = {}

          set_up_parameters_doubling
        end

        def for(action, options = {})
          @action = action
          @verb = options.fetch(:verb, default_verb)
          @request_params = options.fetch(:params, {})
          self
        end

        def add_params(params)
          request_params.merge!(params)
          self
        end

        def on(slice)
          @slice = slice
          self
        end

        def in_context(context)
          @context = context
          self
        end

        def description
          expectation
        end

        def matches?(controller)
          @controller = controller
          ensure_action_and_verb_present!

          Doublespeak.with_doubles_activated do
            context.__send__(verb, action, request_params)
          end

          unpermitted_params.empty?
        end

        def failure_message
          "Expected controller to #{expectation},\n" +
            "but it permitted #{format_param_names(actual_permitted_params)} instead."
        end
        alias failure_message_for_should failure_message

        def failure_message_when_negated
          "Expected controller not to #{expectation}, but it did."
        end
        alias failure_message_for_should_not failure_message_when_negated

        protected

        attr_reader :controller, :double_collections_by_param, :action, :verb,
          :request_params, :expected_permitted_params, :context, :slice

        def expectation
          message = "permit #{format_param_names(expected_permitted_params)}"

          if slice
            message << " for #{slice.inspect}"
          end

          message
        end

        def format_param_names(param_names)
          param_names.map(&:inspect).to_sentence
        end

        def set_up_parameters_doubling
          double_collections_by_param = @double_collections_by_param

          parameters_double_collection =
            Doublespeak.double_collection_for(::ActionController::Parameters)

          double_collections_by_param[nil] = parameters_double_collection

          parameters_double_collection.register_proxy(:permit)

          require_double = parameters_double_collection.register_proxy(:require)

          require_double.to_return do |call|
            key = call.args.first
            return_value = call.return_value

            binding.pry

            double_collections_by_param[key] ||= begin
              required_params_double_collection =
                Doublespeak.double_collection_for(return_value.singleton_class)

              required_params_double_collection.register_proxy(:permit)

              required_params_double_collection
            end
          end
        end

        def actual_permitted_params
          if slice
            permitted_params_for_slice
          else
            all_actual_permitted_params
          end
        end

        def permitted_params_for_slice
          permitted_params_within(double_collections_by_param[slice])
        end

        def all_actual_permitted_params
          double_collections_by_param.map do |_, double_collection|
            permitted_params_within(double_collection)
          end.flatten
        end

        def permitted_params_within(double_collection)
          double_collection.calls_to(:permit).flat_map { |call| call.args }
        end

        def permit_called?
          actual_permitted_params.any?
        end

        def unpermitted_params
          expected_permitted_params - actual_permitted_params
        end

        def verified_permitted_params
          expected_permitted_params & actual_permitted_params
        end

        def ensure_action_and_verb_present!
          if action.blank?
            raise ActionNotDefinedError
          end

          if verb.blank?
            raise VerbNotDefinedError
          end
        end

        def default_verb
          case action
            when :create then :post
            when :update then RailsShim.verb_for_update
          end
        end

        def param_names_as_sentence
          expected_permitted_params.map(&:inspect).to_sentence
        end

        # @private
        class ActionNotDefinedError < StandardError
          def message
            'You must specify the controller action using the #for method.'
          end
        end

        # @private
        class VerbNotDefinedError < StandardError
          def message
            'You must specify an HTTP verb when using a non-RESTful action. For example: for(:authorize, verb: :post)'
          end
        end
      end
    end
  end
end
