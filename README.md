# Cattri

**Cattri** is a minimal-footprint Ruby DSL for defining class-level and instance-level attributes with clarity, safety, and full visibility control — without relying on ActiveSupport.

It offers subclass-safe inheritance, lazy or static defaults, optional coercion, and write-once (`final`) semantics, while remaining lightweight and idiomatic.

---

## ✨ Features

- ✅ Unified `cattri` API for both class and instance attributes
- 🔍 Tracks visibility: `public`, `protected`, `private`
- 🔁 Inheritance-safe attribute copying
- 🧼 Lazy defaults or static values
- 🔒 Write-once `final: true` support
- 👁 Predicate support (`admin?`, etc.)
- 🔍 Introspection: list all attributes and methods
- 🧪 100% test and branch coverage
- 🔌 Zero runtime dependencies

---

## 💡 Why Use Cattri?

Ruby's built-in attribute helpers and Rails' `class_attribute` are either too limited or too invasive. Cattri offers:

| Capability                                     | Cattri | `attr_*` / `cattr_*` | `class_attribute` (Rails) |
|-----------------------------------------------|--------|----------------------|---------------------------|
| Single DSL for class & instance attributes     | ✅     | ❌                    | ❌                         |
| Subclass-safe value & metadata inheritance    | ✅     | ❌                    | ⚠️                         |
| Visibility-aware (`private`, `protected`)     | ✅     | ❌                    | ❌                         |
| Lazy or static defaults                       | ✅     | ⚠️                    | ✅                         |
| Optional coercion or transformation           | ✅     | ❌                    | ⚠️                         |
| Write-once (`final: true`) semantics          | ✅     | ❌                    | ❌                         |

---

## 🚀 Usage Examples

Cattri uses a single DSL method, `cattri`, to define both class-level and instance-level attributes.

Use the `scope:` option to indicate whether the attribute belongs to the class (`:class`) or the instance (`:instance`). If omitted, it defaults to `:instance`.

```ruby
class User
  include Cattri

  # Final class-level attribute
  cattri :type, :standard, final: true, scope: :class

  # Writable class-level attribute
  cattri :config, -> { {} }, scope: :class

  # Final instance-level attribute
  cattri :id, -> { SecureRandom.uuid }, final: true

  # Writable instance-level attributes
  cattri :name, "anonymous" do |value|
    value.to_s.capitalize # custom setter/coercer
  end

  cattri :admin, false, predicate: true

  def initialize(id)
    self.id = id # set the value for `cattri :id`
  end
end

# Class-level access
User.type         # => :standard
User.config       # => {}

# Instance-level access
user = User.new
user.name         # => "anonymous"
user.admin?       # => false
user.id           # => uuid
```

---

## 👇 Accessing Attributes Within the Class

```ruby
class User
  include Cattri

  cattri :id, -> { SecureRandom.uuid }, final: true
  cattri :type, :standard, final: true, scope: :class

  def initialize(id)
    self.id = id                 # Sets instance-level attribute
  end

  def summary
    "#{self.class.type}-#{id}"  # Accesses class-level and instance-level attributes
  end

  def self.default_type
    type  # Same as self.type — resolves on the singleton
  end
end
```

---

## 🧭 Attribute Scope

By default, attributes are defined per-instance. You can change this behavior using `scope:`.

```ruby
class Config
  include Cattri

  cattri :global_timeout, 30, scope: :class
  cattri :retries, 3  # implicitly scope: :instance
end

Config.global_timeout        # => 30

instance = Config.new
instance.retries             # => 3
instance.global_timeout      # => NoMethodError
```

- `scope: :class` defines the attribute on the class (i.e., the singleton).
- `scope: :instance` (or omitting scope) defines the attribute per instance.

---

## 🛡 Final Attributes

```ruby
class Settings
  include Cattri
  cattri :version, -> { "1.0.0" }, final: true, scope: :class
end

Settings.version          # => "1.0.0"
Settings.version = "2.0"  # => Raises Cattri::AttributeError
```

- `final: true, scope: :class` defines a constant class-level attribute. It cannot be reassigned and uses the value provided at definition.
- `final: true` (with instance scope) defines a write-once attribute. If not explicitly set during initialization, the default value will be used.

> Note: `final_cattri` is a shorthand for `cattri(..., final: true)`, included for API symmetry but not required.

---

## 👁 Attribute Exposure

The `expose:` option controls what public methods are generated for an attribute. You can fine-tune whether the reader, writer, or neither is available.

```ruby
class Profile
  include Cattri

  cattri :name, "guest", expose: :read_write
  cattri :token, "secret", expose: :read
  cattri :attempts, 0, expose: :write
  cattri :internal_flag, true, expose: :none
end
```

### Exposure Levels

- `:read_write` — defines both reader and writer
- `:read` — defines a reader only
- `:write` — defines a writer only
- `:none` — defines no public methods (internal only)

> Predicate methods (`admin?`, etc.) are enabled via `predicate: true`.

---

## 🔐 Visibility

Cattri respects Ruby's `public`, `protected`, and `private` scoping when defining methods. You can also explicitly override visibility using `visibility:`.

```ruby
class Document
  include Cattri

  private
  cattri :token

  protected
  cattri :internal_flag

  public
  cattri :title

  cattri :owner, "system", visibility: :protected
end
```

- If defined inside a visibility scope, Cattri applies that visibility automatically
- Use `visibility:` to override the inferred scope
- Applies only to generated methods (reader, writer, predicate), not internal store access

---

## 🔍 Introspection

Enable introspection with:

```ruby
User.with_cattri_introspection

User.attributes              # => [:type, :name, :admin]
User.attribute(:type).final? # => true
User.attribute_methods       # => { type: [:type], name: [:name], admin: [:admin, :admin?] }
User.attribute_source(:name) # => User
```

---

## 📦 Installation

Add to your Gemfile:

```ruby
gem "cattri"
```

Or via Bundler:

```sh
bundle add cattri
```

---

## 🧱 Design Overview

Cattri includes:

- `InternalStore` for final-safe value tracking
- `ContextRegistry` and `Context` for method definition logic
- `Attribute` and `AttributeOptions` for metadata handling
- `Visibility` tracking for DSL-defined methods
- `InitializerPatch` for final attribute enforcement on `#initialize`
- `Dsl` for `cattri` and `final_cattri`
- `Inheritance` to ensure subclass copying

---

## 🧪 Test Coverage

Cattri is tested with 100% line and branch coverage. All dynamic definitions are validated via RSpec, and edge cases are covered, including:

- Predicate methods
- Final value enforcement
- Class vs. instance scope
- Attribute inheritance
- Visibility and expose interaction

---

## Contributing

1. Fork the repo
2. `bundle install`
3. Run the test suite with `bundle exec rake`
4. Submit a pull request – ensure new code is covered and **rubocop** passes

---

## License

This gem is released under the MIT License – see [LICENSE](LICENSE) for details.

## 🙏 Credits

Created with ❤️ by [Nathan Lucas](https://github.com/bnlucas)
