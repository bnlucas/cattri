# Cattri

Cattri is a lightweight Ruby DSL for defining class-level and instance-level attributes with optional defaults, coercion, and reset capabilities.

It provides fine-grained control over attribute behavior, including:

- Class-level attributes (`cattr`) with optional instance accessors
- Instance-level attributes (`iattr`) with coercion and lazy defaults
- Optional locking of class attribute definitions to prevent subclass redefinition
- Simple, expressive DSL for reusable metaprogramming

## ✨ Features

- ✅ Define readable/writable class and instance attributes
- 🧱 Static or callable default values
- 🌀 Optional coercion logic via blocks
- 🧼 Reset attributes to default
- 🔒 Lock class attribute definitions in base class
- 🔍 Introspect attribute definitions and values (optional)

## 📦 Installation

```bash
bundle add cattri
```

Or add to your Gemfile:

```ruby
gem "cattri"
```

## 🚀 Usage

### Class & Instance Attributes

```ruby
class MyConfig
  include Cattri

  cattr :enabled, default: true
  iattr :name, default: "anonymous"
end

MyConfig.enabled # => true
MyConfig.new.name # => "anonymous"
```

### Class Attributes

```ruby
class MyConfig
  extend Cattri::ClassAttributes

  cattr :format, default: :json
  cattr_reader :version, default: "1.0.0"
  cattr :enabled, default: true do |value|
    !!value
  end
end

MyConfig.format           # => :json
MyConfig.format :xml
MyConfig.format           # => :xml

MyConfig.version          # => "1.0.0"
```

#### Instance Access

```ruby
MyConfig.new.format       # => :xml
```

#### Locking Class Attribute Definitions

```ruby
MyConfig.lock_cattrs!
```

This prevents redefinition of existing class attributes in subclasses.

### Instance Attributes

```ruby
class Request
  include Cattri::InstanceAttributes

  iattr :headers, default: -> { {} }
  iattr_writer :raw_body do |val|
    val.to_s.strip
  end
end

req = Request.new
req.headers["Content-Type"] = "application/json"
req.raw_body = "  data  "
```

### Resetting Attributes

```ruby
MyConfig.reset_cattrs!        # Reset all class attributes
MyConfig.reset_cattr!(:format)

req.reset_iattr!(:headers)    # Reset a specific instance attribute
```

## 🔍 Introspection

If you include the `Cattri::Introspection` module:

```ruby
class MyConfig
  include Cattri
  include Cattri::Introspection

  cattr :items, default: []
end

MyConfig.items << :a
MyConfig.snapshot_class_attributes # => { items: [:a] }
```

## 📚 API Overview

| Method                           | Description                                |
|----------------------------------|--------------------------------------------|
| `cattr`, `cattr_reader`          | Define class-level attributes              |
| `iattr`, `iattr_reader`, `iattr_writer` | Define instance-level attributes       |
| `reset_cattr!`, `reset_iattr!`   | Reset specific attributes                 |
| `cattr_definition(:name)`        | Get attribute metadata                    |
| `lock_cattrs!`                   | Prevent redefinition in subclasses        |

## 🧪 Testing

```bash
bundle exec rspec
```

## 💡 Why Cattri?

Cattri provides a cleaner alternative to `class_attribute`, `attr_accessor`, and configuration gems like `Dry::Configurable` or `ActiveSupport::Configurable`, without monkey-patching or runtime surprises.

## 📝 License

MIT © [Nathan Lucas](https://github.com/bnlucas). See [LICENSE](LICENSE).

---

## 🙏 Credits

Created with ❤️ by [Nathan Lucas](https://github.com/bnlucas)
