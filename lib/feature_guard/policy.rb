# frozen_string_literal: true

module FeatureGuard
  module Policy
    # `feature_setting` is used for declared feature methods that the policy
    # does not override directly.
    def initialize(current_user:, feature_setting:)
      @current_user = current_user
      @feature_setting = feature_setting
    end

    # A missing policy predicate falls back to the identically named persisted
    # setting predicate. Defined policy methods fully override that setting.
    def method_missing(method_name, ...)
      return super unless method_name.to_s.end_with?('?')

      persisted_feature_enabled?(method_name)
    end

    def respond_to_missing?(method_name, include_private = false)
      return super unless method_name.to_s.end_with?('?')

      @feature_setting.respond_to?(method_name, include_private) || super
    end

    private

    def persisted_feature_enabled?(method_name)
      return false unless @feature_setting

      unless @feature_setting.respond_to?(method_name)
        raise MissingFeatureColumnError,
              "Missing setting column #{method_name.to_s.delete_suffix('?')} for #{@feature_setting.class.name}."
      end

      @feature_setting.public_send(method_name)
    end
  end
end
