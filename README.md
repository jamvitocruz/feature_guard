# FeatureGuard

FeatureGuard protects Rails controller actions with feature flags stored on an
account's settings record. It also exposes the same checks to views.

## Installation

Add the gem to the Rails application's `Gemfile`:

```ruby
gem "feature_guard"
```

Then install dependencies:

```bash
bundle install
```

## Configuration

Create `config/initializers/feature_guard.rb`:

```ruby
FeatureGuard.configure do |config|
  config.redirect_method = :dashboards_path
end
```

The default values are:

```ruby
redirect_method: :root_path
```

`redirect_method` is combined with the controller's first namespace. For
example, `:dashboards_path` in a `Partner` controller becomes
`partner_dashboards_path`.

## Settings record

The account's settings record must have a boolean attribute for each feature:

```ruby
# current_account.feature_setting
inventory_enabled # true or false
reports_enabled   # true or false
```

For example, an account can expose its settings record like this:

```ruby
class Account < ApplicationRecord
  has_one :feature_setting
end
```

## Protect a controller action

Declare a feature in a controller:

```ruby
class InventoryController < ApplicationController
  feature :inventory_enabled

  def index
  end
end
```

The feature name must exactly match a boolean column on
`current_account.feature_setting`. `feature :inventory_enabled` calls
`inventory_enabled?` on the feature policy. When that method is not defined,
the policy reads `inventory_enabled?` from the settings record. If that column
is missing, FeatureGuard raises `FeatureGuard::MissingFeatureColumnError`.
FeatureGuard adds a `before_action`:

```text
inventory_enabled is true  -> the action runs
inventory_enabled is false -> the request redirects
```

Limit a feature check to specific actions with normal `before_action` options:

```ruby
class InventoryController < ApplicationController
  feature :inventory_enabled, only: :index
end
```

For example, `feature :inventory_access_enabled` requires an
`inventory_access_enabled` settings column and uses
`inventory_access_enabled?` on both the policy and settings record.

## Feature policy

Create a policy in the Rails application and have the host controller provide
one instance per request. Include `FeatureGuard::Policy`; the module provides
the common feature-resolution behavior.

```ruby
# app/policies/feature_policy.rb
class FeaturePolicy
  include FeatureGuard::Policy

  def inventory_enabled?
    current_user.admin?
  end
end
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  private

  def feature_guard_policy
    @feature_guard_policy ||= FeaturePolicy.new(
      current_user: current_user,
      feature_setting: current_account&.feature_setting
    )
  end
end
```

The policy receives the account's `feature_setting` and `current_user`. A
defined policy method fully controls its declared feature. When it is absent,
`FeatureGuard::Policy#method_missing` reads the identically named setting
predicate. Policy and settings names must match exactly.

Define the private `#feature_guard_policy` instance method on the base
controller so all controllers can build a request policy. For namespaced
controllers, define it on that namespace's base controller. If it is missing,
the gem raises `FeatureGuard::MissingPolicyError`.

To use a differently named factory method, select it with the class-level
`feature_guard_policy_method` declaration:

```ruby
feature_guard_policy_method :my_custom_feature_policy
```

## Use a feature in a view

`module_enabled?` is available in controller actions and views:

```erb
<% if module_enabled?(:inventory_enabled) %>
  <%= link_to "Inventory", inventory_path %>
<% end %>
```

You may use `module_enabled?` without declaring `feature :inventory_enabled` in the
controller. Declaring `feature` is only required when you want FeatureGuard to
add the automatic redirect callback.

## Errors and missing settings

- If the account has no settings record, `module_enabled?` returns `false`.
- If the settings record lacks the expected feature column, FeatureGuard raises
  `FeatureGuard::MissingFeatureColumnError`.
- If the base controller does not implement `feature_guard_policy`, FeatureGuard
  raises `FeatureGuard::MissingPolicyError`.
- If the namespaced dashboard route does not exist, FeatureGuard raises
  `FeatureGuard::MissingRouteError`.
