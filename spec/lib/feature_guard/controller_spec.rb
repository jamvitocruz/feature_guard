# frozen_string_literal: true

RSpec.describe FeatureGuard::Controller do # rubocop:disable Metrics/BlockLength
  before do
    FeatureGuard.configuration = FeatureGuard::Configuration.new
    FeatureGuard.configuration.redirect_method = :dashboards_path
  end

  let(:controller) do
    controller_class = Class.new(ActionController::Base) do
      include FeatureGuard::Controller

      class_attribute :policy_class, :current_user

      def partner_dashboards_path
        '/partner/dashboards'
      end

      private

      def feature_guard_policy
        return super unless self.class.policy_class

        @feature_guard_policy ||= self.class.policy_class.new(
          current_user: current_user,
          feature_setting: current_account&.feature_setting
        )
      end
    end
    stub_const('FeatureGuardSpecController', controller_class)
    controller_class.new
  end

  let(:policy_class) { Class.new { include FeatureGuard::Policy } }
  let(:feature_setting) { instance_double('FeatureSetting', inventory_enabled?: true) }
  let(:account) { instance_double('Account', feature_setting: feature_setting) }

  before do
    controller.class.policy_class = policy_class
    allow(controller).to receive(:current_account).and_return(account)
  end

  it 'uses the namespace dashboard path when it exists' do
    allow(controller).to receive(:controller_path).and_return('partner/inventory/transactions')

    expect(controller.send(:feature_guard_redirect_path)).to eq('/partner/dashboards')
  end

  it 'raises an error when the namespace dashboard path does not exist' do
    allow(controller).to receive(:controller_path).and_return('express/inventory/transactions')

    expect { controller.send(:feature_guard_redirect_path) }
      .to raise_error(FeatureGuard::MissingRouteError, /express_dashboards_path/)
  end

  it 'allows a policy method to enable a disabled persisted setting' do
    policy_class = Class.new do
      include FeatureGuard::Policy

      def inventory_enabled?
        true
      end
    end
    controller.class.policy_class = policy_class
    allow(feature_setting).to receive(:inventory_enabled?).and_return(false)

    expect(controller.module_enabled?(:inventory_enabled)).to be(true)
  end

  it 'returns nil for a defined nil policy method' do
    policy_class = Class.new do
      include FeatureGuard::Policy

      def inventory_enabled?
        nil
      end
    end
    controller.class.policy_class = policy_class

    expect(controller.module_enabled?(:inventory_enabled)).to be_nil
  end

  it 'raises an error when the settings column does not exist' do
    setting = Class.new do
      def self.table_name
        'feature_settings'
      end
    end.new
    allow(account).to receive(:feature_setting).and_return(setting)

    expect { controller.module_enabled?(:inventory_enabled) }
      .to raise_error(FeatureGuard::MissingFeatureColumnError, /inventory_enabled/)
  end

  it 'does not use differently named policy methods' do
    policy_class = Class.new do
      include FeatureGuard::Policy

      def inventory_validator?
        true
      end
    end
    controller.class.policy_class = policy_class
    allow(feature_setting).to receive(:inventory_enabled?).and_return(false)

    expect(controller.module_enabled?(:inventory_enabled)).to be(false)
  end

  it 'uses the selected custom policy factory method' do
    controller.class.feature_guard_policy_method :custom_feature_policy
    controller.class.class_attribute :custom_policy
    controller.class.custom_policy = policy_class.new(
      current_user: nil,
      feature_setting: feature_setting
    )
    controller.define_singleton_method(:custom_feature_policy) do
      self.class.custom_policy
    end

    expect(controller.module_enabled?(:inventory_enabled)).to be(true)
  end

  it 'rejects feature names with a predicate marker' do
    expect { controller.class.feature(:inventory_enabled?) }
      .to raise_error(ArgumentError, /must not end with a question mark/)
  end

  context 'without a controller policy' do
    let(:policy_class) { nil }

    it 'raises an error' do
      expect { controller.module_enabled?(:inventory_enabled) }
        .to raise_error(FeatureGuard::MissingPolicyError, /feature_guard_policy/)
    end
  end
end
