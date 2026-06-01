# frozen_string_literal: true

require 'test_helper'

class Micro::Authorization::ModelTest < Minitest::Test
  require 'ostruct'

  def setup
    @user = OpenStruct.new(id: 1)
    @role_permissions = {
      'visit' => {'any' => true},
      'export' => {'except' => ['sales', 'foo']}
    }
  end

  def test_permissions
    authorization = Micro::Authorization::Model.build(
      permissions: @role_permissions,
      context: {
        user: @user,
        to_permit: ['sales', 'index'] # Rails like [controller_name, action_name]
      }
    )

    assert authorization.permissions.to?('visit')
    refute authorization.permissions.to?('export')
  end

  def test_multiple_permissions
    authorization = Micro::Authorization::Model.build(
      permissions: [
        {
          'visit' => {'any' => true},
          'export' => {'except' => ['sales', 'foo']}
        },
        {
          'visit' => {'any' => false},
          'export' => {'any' => true}
        }
      ],
      context: {
        user: @user,
        to_permit: ['dashboard', 'controllers', 'sales', 'index'] # Hanami like
      }
    )

    assert authorization.permissions.to?('visit')
    assert authorization.permissions.to?('export')
  end


  class FooPolicy < Micro::Authorization::Policy
    def index?
      !user.id.nil?
    end
  end

  class BarPolicy < Micro::Authorization::Policy
    def index?
      true
    end
  end

  class BazPolicy < Micro::Authorization::Policy
    def index?(value)
      value == true
    end
  end

  class NumericSubjectPolicy < Micro::Authorization::Policy
    def valid?
      subject.is_a? Numeric
    end

    def number
      subject
    end
  end

  def test_policies_using_the_method_to
    authorization = Micro::Authorization::Model.build(
      permissions: {},
      context: { user: @user }
    )

    refute authorization.to(:foo).index?, "forbids if the policy wasn't added"
    refute authorization.to(:bar).index?, "forbids if the policy wasn't added"
    refute authorization.to(:baz).index?(true), "forbids if the policy wasn't added"
    refute authorization.to(:numeric_subject).valid?, "forbids if the policy wasn't added"

    authorization.add_policies(foo: FooPolicy, bar: BarPolicy, baz: BazPolicy)

    assert authorization.to(:foo).index?
    assert authorization.to(:bar).index?
    assert authorization.to(:baz).index?(true)

    authorization.add_policy(:numeric_subject, NumericSubjectPolicy)

    assert authorization.to(:numeric_subject, subject: 1).valid?
  end

  def test_erro_when_add_policies_with_invalid_data
    authorization = Micro::Authorization::Model.build(
      permissions: {},
      context: { user: @user }
    )

    err = assert_raises(ArgumentError) do
      authorization.add_policies([:foo, FooPolicy])
    end

    assert_equal('policies must be a Hash. e.g: `{policy_name: Micro::Authorization::Policy}`', err.message)
  end

  def test_default_policy_via_to_method
    authorization = Micro::Authorization::Model.build(
      permissions: {},
      context: { user: @user }
    )

    assert authorization.to(:foo).class == Micro::Authorization::Policy
    assert authorization.to(:bar).class == Micro::Authorization::Policy

    authorization.add_policy(:default, FooPolicy)

    assert authorization.to(:foo).class == FooPolicy
    assert authorization.to(:bar).class == FooPolicy
  end

  def test_policy_cache_strategy_via_to_method
    authorization = Micro::Authorization::Model.build(
      permissions: {},
      policies: { bar: BarPolicy },
      context: { user: @user }
    )

    assert authorization.to(:bar).index?

    authorization.to(:bar).class.class_eval do
      class << self
        alias_method :original_new, :new
      end

      def self.new(*args, **kargs)
        raise
      end
    end

    assert authorization.to(:bar).index?

    authorization.to(:bar).class.class_eval do
      class << self
        alias_method :new, :original_new
      end
    end
  end

  def test_default_policy_via_policy_method
    authorization1 = Micro::Authorization::Model.build(
      permissions: {},
      policies: { foo: FooPolicy },
      context: { user: @user }
    )

    assert authorization1.policy.class == authorization1.to(:default).class

    authorization2 = Micro::Authorization::Model.build(
      permissions: {},
      policies: { default: :foo, foo: FooPolicy },
      context: { user: @user }
    )

    assert authorization2.policy.class == authorization2.to(:default).class
  end

  def test_that_to_and_policy_method_has_the_same_behavior
    authorization = Micro::Authorization::Model.build(
      permissions: {},
      policies: { default: FooPolicy, baz: BazPolicy, numeric_subject: NumericSubjectPolicy },
      context: { user: @user }
    )

    assert authorization.policy(:baz).class == authorization.to(:baz).class
    assert authorization.policy(:unknow).class == authorization.to(:unknow).class

    numeric_subject_policy_a = authorization.to(:numeric_subject, subject: 1)
    numeric_subject_policy_b = authorization.policy(:numeric_subject, subject: 1)

    assert numeric_subject_policy_a.number == numeric_subject_policy_b.number
  end

  def test_map_context
    authorization = Micro::Authorization::Model.build(
      permissions: @role_permissions,
      policies: { default: FooPolicy, baz: BazPolicy, numeric_subject: NumericSubjectPolicy },
      context: {
        user: @user,
        permissions: ['dashboard', 'controllers', 'sales', 'index']
      }
    )

    new_authorization = authorization.map(context: [
      'dashboard', 'controllers', 'releases', 'index'
    ])

    refute authorization == new_authorization

    assert new_authorization.permissions.to?('visit')
    assert new_authorization.permissions.to?('export')
  end

  def test_map_policies
    @user.id = nil

    authorization = Micro::Authorization::Model.build(
      permissions: @role_permissions,
      policies: { default: FooPolicy },
      context: {
        user: @user,
        to_permit: ['sales']
      }
    )

    refute authorization.policy.index?
    assert authorization.permissions.to_not?('export')

    new_authorization = authorization.map(policies: { default: BarPolicy })

    assert new_authorization.policy.index?
    assert authorization.permissions.to_not?('export')
  end

  def test_map_with_an_invalid_context
    authorization = Micro::Authorization::Model.build(
      permissions: @role_permissions,
      policies: { default: FooPolicy },
      context: {
        user: @user,
        permissions: ['sales']
      }
    )

    err = assert_raises(ArgumentError) { authorization.map }
    assert_equal('context or policies keywords args must be defined', err.message)
  end
end
