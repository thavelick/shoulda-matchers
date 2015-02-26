require 'unit_spec_helper'

describe Shoulda::Matchers::ActionController::PermitMatcher, type: :controller do
  shared_examples 'basic tests' do
    it 'accepts a subset of the permitted attributes' do
      define_controller_with_strong_parameters(action: :create) do |ctrl|
        params_with_conditional_require(ctrl.params).permit(:name, :age)
      end

      expect(controller).to permit_with_conditional_params(
        permit(:name).for(:create)
      )
    end

    it 'accepts all of the permitted attributes' do
      define_controller_with_strong_parameters(action: :create) do |ctrl|
        params_with_conditional_require(ctrl.params).permit(:name, :age)
      end

      expect(controller).to permit_with_conditional_params(
        permit(:name, :age).for(:create)
      )
    end

    it 'rejects attributes that have not been permitted' do
      define_controller_with_strong_parameters(action: :create) do |ctrl|
        params_with_conditional_require(ctrl.params).permit(:name)
      end

      expect(controller).not_to permit_with_conditional_params(
        permit(:name, :admin).for(:create)
      )
    end

    it 'rejects when #permit has not been called' do
      define_controller_with_strong_parameters(action: :create)

      expect(controller).not_to permit_with_conditional_params(
        permit(:name).for(:create)
      )
    end

    it 'tracks multiple calls to #permit' do
      sets_of_attributes = [
        [:eta, :diner_id],
        [:phone_number, :address_1, :address_2, :city, :state, :zip]
      ]

      define_controller_with_strong_parameters(action: :create) do |ctrl|
        params_with_conditional_require(ctrl.params, :order).
          permit(sets_of_attributes[0])

        params_with_conditional_require(ctrl.params, :diner).
          permit(sets_of_attributes[1])
      end

      expect(controller).to permit_with_conditional_params(
        permit(*sets_of_attributes[0]).for(:create),
        :order
      )

      expect(controller).to permit_with_conditional_params(
        permit(*sets_of_attributes[1]).for(:create),
        :diner
      )
    end
  end

  it 'requires an action' do
    assertion = -> { expect(controller).to permit(:name) }

    define_controller_with_strong_parameters

    expect(&assertion).to raise_error(described_class::ActionNotDefinedError)
  end

  it 'requires a verb for a non-restful action' do
    define_controller_with_strong_parameters

    assertion = lambda do
      expect(controller).to permit(:name).for(:authorize)
    end

    expect(&assertion).to raise_error(described_class::VerbNotDefinedError)
  end

  context 'when operating on the entire params hash' do
    include_context 'basic tests' do
      def permit_with_conditional_params(permit, params = {})
        permit
      end

      def params_with_conditional_require(params, *filters)
        params
      end
    end
  end

  context 'when operating on a slice of the params hash' do
    include_context 'basic tests' do
      def permit_with_conditional_params(permit, params = { user: {} })
        permit.add_params(params)
      end

      def params_with_conditional_require(params, *filters)
        if filters.none?
          filters = [:user]
        end

        params.require(*filters)
      end
    end

    it 'rejects if asserting that parameters were not permitted, but on the wrong slice' do
      define_controller_with_strong_parameters(action: :create) do
        params.require(:order).permit(:eta, :diner_id)
      end

      expect(controller).
        not_to permit(:eta, :diner_id).
        for(:create, params: { order: {} }).
        on(:something_else)
    end
  end

  it 'can be used more than once in the same test' do
    define_controller_with_strong_parameters(action: :create) do
      params.permit(:name)
    end

    expect(controller).to permit(:name).for(:create)
    expect(controller).not_to permit(:admin).for(:create)
  end

  it 'allows extra parameters to be passed to the action if it requires them' do
    options = {
      controller_name: 'Posts',
      action: :show,
      routes: -> { get '/posts/:slug', to: 'posts#show' }
    }

    define_controller_with_strong_parameters(options) do
      params.permit(:name)
    end

    expect(controller).
      to permit(:name).
      for(:show, verb: :get, params: { slug: 'foo' })
  end

  it 'works with #update specifically' do
    define_controller_with_strong_parameters(action: :update) do
      params.permit(:name)
    end

    expect(controller).
      to permit(:name).
      for(:update, params: { id: 1 })
  end

  describe '#matches?' do
    it 'does not raise an error when #fetch was used instead of #require (issue #495)' do
      matcher = permit(:eta, :diner_id).for(:create)
      matching = -> { matcher.matches?(controller) }

      define_controller_with_strong_parameters(action: :create) do
        params.fetch(:order, {}).permit(:eta, :diner_id)
      end

      expect(&matching).not_to raise_error
    end

    context 'stubbing params on the controller' do
      it 'still allows the original params hash to be modified and accessed prior to the call to #require' do
        actual_user_params = nil
        actual_foo_param = nil
        matcher = permit(:name).for(
          :create,
          params: { user: { some: 'params' } }
        )

        define_controller_with_strong_parameters(action: :create) do
          params[:foo] = 'bar'
          actual_foo_param = params[:foo]
          actual_user_params = params[:user]

          params.permit(:name)
        end

        matcher.matches?(controller)

        expect(actual_user_params).to eq('some' => 'params')
        expect(actual_foo_param).to eq 'bar'
      end

      it 'still allows #require to return a slice of the params' do
        expected_user_params = { foo: 'bar' }
        actual_user_params = nil
        matcher = permit(:name).for(
          :update,
          params: { id: 1, user: expected_user_params }
        )

        define_controller_with_strong_parameters(action: :update) do
          actual_user_params = params.require(:user)
          actual_user_params.permit(:name)
        end

        matcher.matches?(controller)

        expect(actual_user_params).to eq expected_user_params
      end

      it 'does not permanently stub the params hash' do
        matcher = permit(:name).for(:create)
        params_access = -> { controller.params.require(:user) }

        define_controller_with_strong_parameters(action: :create)

        matcher.matches?(controller)

        expect(&params_access).
          to raise_error(::ActionController::ParameterMissing)
      end

      it 'prevents permanently stubbing params on error' do
        matcher = permit(:name).for(:create)
        params_access = -> { controller.params.require(:user) }

        define_controller_raising_exception

        begin
          matcher.matches?(controller)
        rescue simulated_error_class
        end

        expect(&params_access).
          to raise_error(::ActionController::ParameterMissing)
      end
    end
  end

  describe '#description' do
    it 'returns the correct string' do
      options = { action: :create, method: :post }

      define_controller_with_strong_parameters(options) do
        params.permit(:name, :age)
      end

      matcher = described_class.new([:name, :age, :height]).for(:create)
      expect(matcher.description).
        to eq 'permit POST #create to receive parameters :name, :age, and :height'
    end

    context 'when a verb is specified' do
      it 'returns the correct string' do
        options = { action: :some_action }

        define_controller_with_strong_parameters(options) do
          params.permit(:name, :age)
        end

        matcher = described_class.new([:name]).
          for(:some_action, verb: :put)
        expect(matcher.description).
          to eq 'permit PUT #some_action to receive parameters :name'
      end
    end
  end

  describe 'positive failure message' do
    it 'includes all missing attributes' do
      define_controller_with_strong_parameters(action: :create) do
        params.permit(:name, :age)
      end

      assertion = lambda do
        expect(@controller).
          to permit(:name, :age, :city, :country).
          for(:create)
      end

      message =
        "Expected controller to permit :name, :age, :city, and :country,\n" +
        "but it permitted :name and :age instead."

      expect(&assertion).to fail_with_message(message)
    end
  end

  describe 'negative failure message' do
    it 'includes all attributes that should not have been permitted but were' do
      define_controller_with_strong_parameters(action: :create) do
        params.permit(:name, :age)
      end

      assertion = lambda do
        expect(controller).not_to permit(:name, :age).for(:create)
      end

      message =
        "Expected controller not to permit :name and :age,\n" +
        "but it did."

      expect(&assertion).to fail_with_message(message)
    end
  end

  describe '#for' do
    context 'when given :create' do
      it 'POSTs to the controller' do
        controller = ActionController::Base.new
        context = build_context
        matcher = permit(:name).for(:create).in_context(context)

        matcher.matches?(controller)

        expect(context).to have_received(:post).with(:create, {})
      end
    end

    context 'when given :update' do
      if rails_gte_4_1?
        it 'PATCHes to the controller' do
          controller = ActionController::Base.new
          context = build_context
          matcher = permit(:name).for(:update).in_context(context)

          matcher.matches?(controller)

          expect(context).to have_received(:patch).with(:update, {})
        end
      else
        it 'PUTs to the controller' do
          controller = ActionController::Base.new
          context = build_context
          matcher = permit(:name).for(:update).in_context(context)

          matcher.matches?(controller)

          expect(context).to have_received(:put).with(:update, {})
        end
      end
    end

    context 'when given a custom action and verb' do
      it 'calls the action with the verb' do
        controller = ActionController::Base.new
        context = build_context
        matcher = permit(:name).
          for(:hide, verb: :delete).
          in_context(context)

        matcher.matches?(controller)

        expect(context).to have_received(:delete).with(:hide, {})
      end
    end
  end

  let(:simulated_error_class) do
    Class.new(StandardError)
  end

  def define_controller_with_strong_parameters(options = {}, &action_body)
    model_name = options.fetch(:model_name, 'User')
    controller_name = options.fetch(:controller_name, 'UsersController')
    collection_name = controller_name.
      to_s.sub(/Controller$/, '').underscore.
      to_sym
    action_name = options.fetch(:action, :some_action)
    routes = options.fetch(:routes, -> { resources collection_name })

    define_model(model_name)

    controller_class = define_controller(controller_name) do
      define_method action_name do
        if action_body
          if action_body.arity == 0
            instance_eval(&action_body)
          else
            action_body.call(self)
          end
        end

        render nothing: true
      end
    end

    setup_rails_controller_test(controller_class)

    define_routes(&routes)

    controller_class
  end

  def define_controller_raising_exception
    _simulated_error_class = simulated_error_class

    controller_class = define_controller('Examples') do
      define_method :create do
        raise _simulated_error_class
      end
    end

    setup_rails_controller_test(controller_class)

    define_routes do
      get 'examples', to: 'examples#create'
    end

    controller_class
  end

  def build_context
    double('context', post: nil, put: nil, patch: nil, delete: nil)
  end
end
