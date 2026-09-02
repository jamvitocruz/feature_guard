# frozen_string_literal: true

module FeatureGuard
  module Policy
    # `feature_setting` must respond to feature predicate methods such as
    # `inventory_enabled?`. Set `impersonating` when the request should bypass
    # all persisted feature checks.
    def initialize(current_user:, feature_setting:, impersonating: false)
      @current_user = current_user
      @feature_setting = feature_setting
      @impersonating = impersonating
    end

    # Calls the policy method derived from a feature column. A policy method
    # returning true enables access; false or nil uses the persisted setting.
    def feature_enabled?(method_name)
      return true if @impersonating

      public_send(method_name) || persisted_feature_enabled?(method_name)
    end

    def method_missing(method_name, ...)
      return super unless feature_method?(method_name)

      persisted_feature_enabled?(method_name)
    end

    def respond_to_missing?(method_name, include_private = false)
      feature_method?(method_name) || super
    end

    private

    # A missing settings record disables the feature. A missing predicate on a
    # present settings record is a configuration error, not a disabled flag.
    def persisted_feature_enabled?(method_name)
      return false unless @feature_setting

      return @feature_setting.public_send(method_name) if @feature_setting.respond_to?(method_name)

      raise MissingFeatureColumnError,
            "Missing setting column #{method_name.to_s.delete_suffix('?').inspect}"
    end

    # FeatureGuard only treats names ending in `_enabled?` as feature checks.
    def feature_method?(method_name)
      method_name.to_s.end_with?('_enabled?')
    end
  end
end
