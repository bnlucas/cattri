# Cattri

A **minimal‑footprint** DSL for defining **class‑level** and **instance‑level** attributes in Ruby, with first‑class support for custom defaults, coercion, visibility tracking, and safety‑first error handling.

---

## Why another attribute DSL?

| Capability | Cattri | `attr_*` / `cattr_*` (Ruby / ActiveSupport) | `dry-configurable` |
|------------|:------:|:-------------------------------------------:|:------------------:|
| **Single DSL for class *and* instance attributes** | ✅ | ❌ (separate APIs) | ⚠️ (config only) |
| **Per‑subclass deep copy of attribute metadata & values** | ✅ | ❌ | ❌ |
| **Built‑in visibility tracking (`public` / `protected` / `private`)** | ✅ | ❌ | ❌ |
| **Lazy or static *default* values** | ✅ | ⚠️ (writer‑based) | ✅ |
| **Optional *coercion* via custom setter block** | ✅ | ❌ | ✅ |
| **Read‑only / write‑only flags** | ✅ | ⚠️ (reader / writer macros) | ❌ |
| **Introspection helpers (`snapshot_*`)** | ✅ | ❌ | ⚠️ via internals |
| **Clear, granular error hierarchy** | ✅ | ❌ | ✅ |
| **Zero runtime dependencies** | ✅ | ⚠️ (ActiveSupport) | ✅ |

> **TL;DR** – If you need lightweight, _Rails‑agnostic_ attribute helpers that play nicely with inheritance and don’t leak state between subclasses, Cattri is for you.

---

## Installation

```bash
bundle add cattri     # Ruby ≥ 2.7
```

Or in your Gemfile:

```ruby
gem "cattri"
```

---

## Quick start

```ruby
class Config
  include Cattri          # exposes `cattr` & `iattr`

  # -- class‑level ----------------------------------
  cattr :enabled,  default: true
  cattr :timeout,  default: -> { 5.0 }, instance_reader: false

  # -- instance‑level -------------------------------
  iattr :name,     default: "anonymous"
  iattr :age,      default: 0 do |val|                 # coercion block
    Integer(val)
  end
end

Config.enabled        # => true
Config.enabled = false
Config.new.age = "42" # => 42
```

---

## Defining attributes

### Class attributes (`cattr`)

```ruby
cattr :log_level, default: :info,
                  access:  :protected,     # respects current visibility by default
                  readonly: false,
                  instance_reader: true do |value|
                    value.to_sym
                  end
```

### Instance attributes (`iattr`)

```ruby
iattr :token, default: -> { SecureRandom.hex(8) },
              reader:  true,
              writer:  false                  # read‑only
```

Both forms accept:

| Option | Purpose |
| ------ | ------- |
| `default:` | Static value or callable (`Proc`) evaluated lazily. |
| `access:` | Override inferred visibility (`:public`, `:protected`, `:private`). |
| `reader:` / `writer:` | Disable reader or writer for instance attributes. |
| `readonly:` | Shorthand for class attributes (`writer` is always present). |
| `instance_reader:` | Expose class attribute as instance reader (default: **true**). |

If you pass a block, it’s treated as a **coercion setter** and receives the incoming value.

---

## Visibility tracking

Cattri watches calls to `public`, `protected`, and `private` while you define methods:

```ruby
class Secrets
  include Cattri

  private
  cattr :api_key
end

Secrets.private_methods.include?(:api_key)   # => true
```

No boilerplate—attributes inherit the visibility that was in effect at the call site.

---

## Safe inheritance

Subclassing copies both **metadata** and **current values**, using defensive `#dup` where possible and falling back safely when objects are frozen or not duplicable:

```ruby
class Base
  include Cattri
  cattr :settings, default: {}
end

class Child < Base; end

Base.settings[:foo]  = 1
Child.settings       # => {}  (isolated copy)
```

---

## Introspection helpers

Add `include Cattri::Introspection` (or `extend` for class‑only use) to snapshot live values:

```ruby
Config.snapshot_cattrs   # => { enabled: false, timeout: 5.0 }
instance.snapshot_iattrs # => { name: "bob", age: 42 }
```

Great for debugging or test assertions.

---

## Error handling

All errors inherit from `Cattri::Error`, allowing a single rescue for any gem‑specific issue.

| Error class | Raised when… |
|-------------|--------------|
| `Cattri::AttributeDefinedError` | an attribute is declared twice on the same level |
| `Cattri::AttributeDefinitionError` | method generation (`define_method`) fails |
| `Cattri::UnsupportedTypeError` | an internal API receives an unknown type |
| `Cattri::AttributeError` | generic superclass for attribute‑related issues |

Example:

```ruby
begin
  class Foo
    include Cattri
    cattr :foo
    cattr :foo   # duplicate
  end
rescue Cattri::AttributeDefinedError => e
  warn e.message   # => "Class attribute :foo has already been defined"
rescue Cattri::AttributeError => e
  warn e.message   # => Catch-all for any error raised within attributes
end
```

---

## Comparison with standard patterns

* **Core Ruby macros** (`attr_accessor`, `cattr_accessor`) are simple but global—attributes bleed into subclasses and lack defaults or coercion.
* **ActiveSupport** extends the API but still relies on mutable class variables and offers no visibility control.
* **Dry‑configurable** is robust yet heavyweight when you only need a handful of attributes outside a full config object.

Cattri sits in the sweet spot: **micro‑sized (~200 LOC)**, dependency‑free, and purpose‑built for attribute declaration.

---

## Testing tips

* Use `include Cattri::Introspection` in spec helper files to capture snapshots before/after mutations.
* Rescue `Cattri::Error` in high‑level test helpers to assert failures without coupling to sub‑class names.

---

## Contributing

1. Fork the repo
2. `bundle install`
3. Run the test suite with `bundle exec rake`
4. Submit a pull request – ensure new code is covered and **rubocop** passes.

---

## License

This gem is released under the MIT License – see See [LICENSE](LICENSE) for details.

## 🙏 Credits

Created with ❤️ by [Nathan Lucas](https://github.com/bnlucas)
