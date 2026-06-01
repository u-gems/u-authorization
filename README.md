<p align="center">
  <h1 align="center">🔐 µ-authorization</h1>
  <p align="center"><i>Authorization and role management for Ruby, with no runtime dependencies.</i></p>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/u-authorization">
    <img alt="Gem" src="https://img.shields.io/gem/v/u-authorization.svg?style=flat-square">
  </a>
  <a href="https://github.com/serradura/u-authorization/actions/workflows/ci.yml">
    <img alt="Build Status" src="https://github.com/serradura/u-authorization/actions/workflows/ci.yml/badge.svg">
  </a>
  <br/>
  <a href="https://qlty.sh/gh/serradura/projects/u-authorization"><img src="https://qlty.sh/gh/serradura/projects/u-authorization/maintainability.svg" alt="Maintainability" /></a>
  <a href="https://qlty.sh/gh/serradura/projects/u-authorization"><img src="https://qlty.sh/gh/serradura/projects/u-authorization/coverage.svg" alt="Code Coverage" /></a>
  <br/>
  <img src="https://img.shields.io/badge/Ruby%20%3E%3D%202.7%2C%20%3C%3D%20Head-ruby.svg?colorA=444&colorB=333" alt="Ruby">
  <img src="https://img.shields.io/badge/Rails%20%3E%3D%206.0%2C%20%3C%3D%20Edge-rails.svg?colorA=444&colorB=333" alt="Rails">
</p>

> [!IMPORTANT]
> **Stable and feature-complete.** `u-authorization` has no new features planned. Its public API is frozen and backward compatible, and ongoing work is limited to keeping it running on current and future Ruby versions. You can depend on it without expecting breaking changes.
>
> A major version bump signals only that an old Ruby version was dropped from the supported matrix, which is a dependency-floor change under SemVer. Your code keeps working.

`u-authorization` splits authorization into two layers that you can use together or on their own:

1. **Permissions** answer "is this role allowed to use this feature, in this context?". A role is plain data (a Hash, or JSON loaded from a database), so you can change who can do what without redeploying.
2. **Policies** answer "is this user allowed to act on this specific record?". A policy is a small Ruby class, similar to [Pundit](https://github.com/varvet/pundit), that returns `true` or `false` and defaults to denying anything it doesn't recognize.

The two layers are independent, and you pick the right one for each check. Use permissions to gate a feature by role and context, which fits a controller `before_action`. Use a policy to decide access to a single record. An authorization object carries the current user, the request context, the role's permissions, and the policies for one request, so both checks are available from the same place.

## Table of contents

- [Table of contents](#table-of-contents)
- [Installation](#installation)
- [Supported versions](#supported-versions)
- [Quick start](#quick-start)
- [Permissions](#permissions)
  - [Roles are plain data](#roles-are-plain-data)
  - [Permission rules](#permission-rules)
  - [Context matching and dot notation](#context-matching-and-dot-notation)
  - [Checking permissions](#checking-permissions)
  - [Multiple roles](#multiple-roles)
- [Policies](#policies)
  - [Defining a policy](#defining-a-policy)
  - [The subject](#the-subject)
  - [Reading permissions inside a policy](#reading-permissions-inside-a-policy)
- [The authorization object](#the-authorization-object)
  - [Building it](#building-it)
  - [Asking about permissions](#asking-about-permissions)
  - [Fetching policies](#fetching-policies)
  - [Registering policies](#registering-policies)
  - [Cloning with map](#cloning-with-map)
- [Using it with Rails](#using-it-with-rails)
- [Comparison with Pundit and CanCanCan](#comparison-with-pundit-and-cancancan)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)
- [Code of conduct](#code-of-conduct)

## Installation

Add the gem to your `Gemfile`:

```ruby
gem 'u-authorization'
```

Then run `bundle install`. Or install it directly:

```bash
gem install u-authorization
```

Require it (or let Bundler do it for you):

```ruby
require 'u-authorization'
```

## Supported versions

The gem requires Ruby `>= 2.7` and is tested on CI against Ruby 2.7 through the current development build. It has no runtime dependencies and works inside any Rails `>= 6.0` application, but it does not depend on Rails or ActiveModel, so you can use it in plain Ruby, Hanami, Sinatra, or a script.

## Quick start

Here is a full example using `OpenStruct` to stand in for a user and a database record. It defines a role, a policy, builds an authorization object, and asks it questions.

```ruby
require 'ostruct'
require 'u-authorization'

# 1. Roles are data. Map each feature to a rule.
module Permissions
  ADMIN = {
    'visit'  => { 'any' => true },
    'export' => { 'any' => true }
  }

  USER = {
    'visit'  => { 'except' => ['billings'] },
    'export' => { 'except' => ['sales'] }
  }

  ALL = { 'admin' => ADMIN, 'user' => USER }

  def self.to(role)
    ALL.fetch(role, USER)
  end
end

# 2. Policies are classes. Predicate methods return true or false.
class SalesPolicy < Micro::Authorization::Policy
  def edit?(record)
    user.id == record.user_id
  end
end

user = OpenStruct.new(id: 1, role: 'user')

# 3. Build the authorization object for this request.
authorization = Micro::Authorization::Model.build(
  permissions: Permissions.to(user.role),
  policies: { default: :sales, sales: SalesPolicy },
  context: {
    user: user,
    to_permit: ['dashboard', 'controllers', 'sales', 'index']
  }
)

# 4a. Ask about feature permissions for the current context.
authorization.permissions.to?('visit')  # => true
authorization.permissions.to?('export') # => false

# 4b. Ask the same feature about a different context.
can_export = authorization.permissions.to('export')
can_export.context?('billings') # => true
can_export.context?('sales')    # => false

# 4c. Ask a policy about a record.
charge = OpenStruct.new(id: 2, user_id: user.id)

authorization.to(:sales).edit?(charge) # => true
authorization.policy.edit?(charge)     # => true (uses the default policy)
```

## Permissions

A permission check answers one question: given a role and the context the request is happening in, is a feature allowed?

### Roles are plain data

A role is a Hash whose keys are feature names and whose values are rules:

```ruby
role = {
  'visit'  => { 'only'   => ['users'] },
  'export' => { 'only'   => ['users.reports'] },
  'manage' => { 'any'    => false }
}
```

Because a role is plain data, it serializes cleanly. You can store roles as JSON in a database, edit them through an admin screen, and load them at runtime without touching code:

```ruby
require 'json'

roles = JSON.parse(current_account.roles_json)
permissions = Micro::Authorization::Permissions.new(roles['user'], context: [])
```

### Permission rules

Each feature maps to one of these rules:

| Rule                    | Meaning                                        |
| ----------------------- | ---------------------------------------------- |
| `true`                  | Allowed in every context.                      |
| `false`                 | Denied in every context.                       |
| missing key or `nil`    | Denied.                                        |
| `{ 'any' => true }`     | Allowed in every context.                      |
| `{ 'any' => false }`    | Denied in every context.                       |
| `{ 'only' => [...] }`   | Allowed only in the listed contexts.           |
| `{ 'except' => [...] }` | Allowed everywhere except the listed contexts. |

`{ 'any' => nil }` and any unrecognized key (for example `{ 'sometimes' => [...] }`) raise `NotImplementedError`, so a malformed role fails loudly instead of silently granting or denying access.

### Context matching and dot notation

The context is an array of strings that describes where the request is happening. In a Rails controller that is usually `[controller_name, action_name]`, but it can be any list of identifiers. Matching is case insensitive; both the context and the rule values are downcased before comparison.

A single string in `only` or `except` matches when the context includes it:

```ruby
role = { 'visit' => { 'only' => ['users'] } }
permissions = Micro::Authorization::Permissions.new(role, context: [])

permissions.to('visit').context?(['users'])  # => true
permissions.to('visit').context?(['sales'])  # => false
```

A string with dots, such as `'users.reports'`, splits on the dot and requires every segment to be present in the context. Entries in the array are still combined with OR, so the rule means "users and reports, or any other listed entry":

```ruby
role = { 'export' => { 'only' => ['users.reports'] } }
permissions = Micro::Authorization::Permissions.new(role, context: [])

permissions.to('export').context?(['users', 'reports']) # => true
permissions.to('export').context?(['users'])            # => false
```

### Checking permissions

`Micro::Authorization::Permissions.new(role, context:)` returns a permissions model bound to a context. From there you have two ways to ask questions.

Use `to?` and `to_not?` to check a feature against the context the model was built with. Pass a single feature or an array, in which case every feature must be allowed:

```ruby
role = { 'visit' => true, 'comment' => false }
permissions = Micro::Authorization::Permissions.new(role, context: ['sales', 'index'])

permissions.to?('visit')                # => true
permissions.to?('comment')              # => false
permissions.to?(['visit', 'comment'])   # => false (comment is denied)
permissions.to_not?('comment')          # => true
```

Use `to(feature)` to get a checker you can test against any context with `context?`, regardless of the model's own context:

```ruby
role = {
  'visit'   => { 'any' => true },
  'comment' => { 'except' => ['sales'] }
}
permissions = Micro::Authorization::Permissions.new(role, context: ['sales', 'index'])

can_comment = permissions.to('comment')
can_comment.context?('invoices') # => true
can_comment.context?('sales')    # => false

can_comment.features # => ['comment'] (the features this checker verifies)
```

The model caches each `to?` result per feature, so repeated checks in the same request are cheap.

### Multiple roles

Pass an array of roles to grant a user the union of their permissions. A feature is allowed when at least one role allows it:

```ruby
analytics = { 'export' => { 'only' => ['reports'] } }
support   = { 'export' => { 'only' => ['users.reports'] } }

permissions = Micro::Authorization::Permissions.new([analytics, support], context: [])

permissions.to('export').context?(['sales', 'reports']) # => true (granted by analytics)
permissions.to('export').context?(['users', 'reports']) # => true (granted by support)
```

## Policies

Permissions decide what a role can do in a place. Policies decide what a user can do to a record. A policy is a class with predicate methods, in the style of Pundit.

### Defining a policy

Subclass `Micro::Authorization::Policy` and define methods that end in `?`. Inside a policy you can read `user` (an alias of `current_user`), `subject`, `context`, and `permissions`:

```ruby
class CommentPolicy < Micro::Authorization::Policy
  def edit?(comment)
    user.id == comment.author_id
  end
end

policy = CommentPolicy.new({ user: current_user })
policy.edit?(comment) # => true or false
```

Any predicate method you have not defined returns `false`. Deny by default is the standard behavior, so a feature you forget to handle stays forbidden.

```ruby
policy = Micro::Authorization::Policy.new({})

policy.index?         # => false
policy.show?(record)  # => false
```

Calling a method that does not end in `?` raises `NoMethodError`, so typos in real method names still surface.

Inside a policy, `current_user` reads `context[:user]` first, then falls back to `context[:current_user]`.

### The subject

A policy can receive the record it is about in two ways. You can pass it as the second argument when constructing the policy, and read it through `subject`:

```ruby
class RecordPolicy < Micro::Authorization::Policy
  def show?
    user.id == subject.user_id
  end
end

RecordPolicy.new({ user: current_user }, record).show?
```

Or you can pass it as an argument to the predicate method, which is handy when one policy instance answers questions about several records:

```ruby
class RecordPolicy < Micro::Authorization::Policy
  def show?(record)
    user.id == record.user_id
  end
end

policy = RecordPolicy.new({ user: current_user })
policy.show?(record_a) # => true
policy.show?(record_b) # => false
```

### Reading permissions inside a policy

A policy can combine record-level checks with feature permissions. When the authorization object builds a policy it passes the permissions in, so `permissions` is available inside:

```ruby
class ReportPolicy < Micro::Authorization::Policy
  def show?(report)
    permissions.to?('visit') && current_user.id == report.owner_id
  end
end
```

## The authorization object

`Micro::Authorization::Model` ties a user, a context, a role's permissions, and a set of policies into a single object for the current request.

### Building it

Use `Model.build` with three keyword arguments. `policies` is optional:

```ruby
authorization = Micro::Authorization::Model.build(
  permissions: Permissions.to(user.role),
  policies: { default: SalesPolicy, sales: SalesPolicy },
  context: {
    user: user,
    to_permit: ['sales', 'index']
  }
)
```

The `context` Hash is read like this:

- `:to_permit` (or its alias `:permissions`) is the context used for permission checks. One of them is required if you want to check permissions.
- `:user` is the current user. It becomes `user` / `current_user` inside policies.
- Every other key stays in the context and is handed to policies, so a policy can read anything else you put there.

### Asking about permissions

`authorization.permissions` returns the permissions model described above, so the full `to?`, `to_not?`, and `to(...).context?` interface is available:

```ruby
authorization.permissions.to?('visit')           # => true
authorization.permissions.to('export').context?('sales') # => false
```

### Fetching policies

`to(key, subject: nil)` looks up a registered policy by name, builds it with the current context and permissions, and returns the instance:

```ruby
authorization.to(:sales).edit?(charge)
```

`policy(key = :default, subject: nil)` does the same but defaults to the `:default` policy, which reads well when you have one main policy per request:

```ruby
authorization.policy.edit?(charge)         # uses :default
authorization.policy(:sales).edit?(charge) # same as to(:sales)
```

If you ask for a key that was never registered, you get the base `Micro::Authorization::Policy`, which denies every predicate. Unknown features are forbidden rather than raising.

Policy instances are cached per key, so calling `to(:sales)` repeatedly returns the same object within a request. Passing a `subject:` builds a fresh instance bound to that subject:

```ruby
authorization.to(:report, subject: report).show?
```

### Registering policies

You can register policies when building the object through the `policies:` keyword, or afterward with `add_policy` and `add_policies`:

```ruby
authorization.add_policy(:sales, SalesPolicy)
authorization.add_policies(sales: SalesPolicy, report: ReportPolicy)
```

`add_policies` expects a Hash and raises `ArgumentError` otherwise.

The `:default` key is special. It can hold a policy class, or a Symbol that points at another registered policy, so you can name one of your policies as the default:

```ruby
Micro::Authorization::Model.build(
  permissions: role,
  policies: { default: :sales, sales: SalesPolicy },
  context: { user: user }
)
```

### Cloning with map

`map` returns a new authorization object, replacing the context, the policies, or both. Whatever you leave out is carried over from the original, and the original is left untouched, which helps when one request needs to check several contexts:

```ruby
on_releases = authorization.map(context: ['dashboard', 'releases', 'index'])

on_releases.permissions.to?('visit') # checked against the new context
authorization.equal?(on_releases)    # => false

with_admin_policy = authorization.map(policies: { default: AdminPolicy })
```

Calling `map` without `context:` or `policies:` raises `ArgumentError`, since there would be nothing to change.

## Using it with Rails

The context maps naturally onto a Rails controller. Using `controller_path.split('/') + [action_name]` keeps namespaced controllers distinct, so `Admin::UsersController#index` becomes `['admin', 'users', 'index']`. A common setup builds the authorization object once per request and exposes a helper:

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  private

  def authorization
    @authorization ||= Micro::Authorization::Model.build(
      permissions: current_user.role_permissions, # a Hash, maybe loaded from the DB
      policies: { default: :record, record: RecordPolicy },
      context: {
        user: current_user,
        to_permit: controller_path.split('/') + [action_name]
      }
    )
  end

  def authorize_visit!
    redirect_to root_path unless authorization.permissions.to?('visit')
  end
end
```

```ruby
class ReportsController < ApplicationController
  before_action :authorize_visit!

  def show
    @report = Report.find(params[:id])
    redirect_to reports_path unless authorization.policy.show?(@report)
  end
end
```

Because roles are data, `current_user.role_permissions` can come straight from a column or an associated table, which lets non-developers manage roles through your own admin tools.

## Comparison with Pundit and CanCanCan

All three gems solve authorization, with different shapes.

- [Pundit](https://github.com/varvet/pundit) is built around policy classes, one per resource. `u-authorization` has the same idea in its `Policy` layer, and adds a separate permissions layer for role and context checks. Pundit leaves roles to you.
- [CanCanCan](https://github.com/CanCanCommunity/cancancan) centralizes rules in one `Ability` class written in Ruby. `u-authorization` keeps role rules as data instead of code, so they can be stored and edited outside the codebase, and keeps record-level logic in policy classes.

Reasons you might reach for `u-authorization`:

- You want roles defined as data (Hash or JSON) so they can live in a database and change without a deploy.
- You want permission checks that are aware of the controller and action, not only the model.
- You want a small library with no runtime dependencies.
- You want role and context checks and record-level checks to stay separate instead of merging into one concept.

If you only need record-level policies, Pundit is a fine and popular choice. If you prefer one central Ruby file of abilities, CanCanCan fits well.

## Development

After cloning the repository, install dependencies and set up the project:

```bash
bin/setup
```

Run the test suite, which is the default Rake task:

```bash
bundle exec rake test
# or simply
bundle exec rake
```

Open a console with the gem loaded to experiment:

```bash
bin/console
```

To run the suite across Ruby versions locally, use [mise](https://mise.jdx.dev). The `.tool-versions` file pins the project's default Ruby; add the versions you want to cover and run the suite under each. CI runs the full matrix, from Ruby 2.7 through the current development build, defined in `.github/workflows/ci.yml`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/serradura/u-authorization. Please add or update tests for any behavior you change; the test suite is the contract for the public API.

1. Fork the repository.
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Add tests and make them pass with `bundle exec rake test`.
4. Commit your changes and open a pull request.

Everyone interacting in the project's codebases and issue trackers is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).

## Code of conduct

Everyone interacting in the µ-authorization project is expected to follow the [code of conduct](CODE_OF_CONDUCT.md).
