# frozen_string_literal: true

require 'rails_feature_guard'

RSpec.describe FeatureGuard do
  it 'has a version number' do
    expect(FeatureGuard::VERSION).not_to be nil
  end
end
