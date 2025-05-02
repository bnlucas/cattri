## [0.2.1] - 2025-05-01

- Fixed an issue where only `final: true` instance variables defined on the current/class had their values applied.
  - Now walks the ancestor tree to ensure all attributes get set.

  ```ruby
  module Options
    include Cattri

    cattri :enabled, true, final: true # wasn't being set previously
  end

  class Attribute
    include Options
  
    def initialize(enabled: true)
      seld.enabled = enabled
    end
  end
  ```
- Cleanup of `cattri.gemspec` and `bin/console`.

## [0.2.0] - 2025-05-01

### Changed

- Replaced `cattr` and `iattr` with unified `cattri` DSL
  - All attributes now use `cattri`, with `scope: :class` or `scope: :instance`
  - `iattr` and `cattr` are no longer public API

- Attribute behavior is now centralized via:
  - `Cattri::Attribute` and `Cattri::AttributeOptions`
  - `Cattri::Context` and `ContextRegistry`
  - `Cattri::InternalStore` for safe write-once value storage

- Final attributes (`final: true`) now enforced at the store level, with safe write-once semantics
- Visibility and exposure are fully separated:
  - `visibility: :public|:protected|:private` sets method scope
  - `expose: :read_write|:read|:write|:none` controls which methods are generated
- New predicate handling via `predicate: true`, with visibility inheritance

### Added

- Support for `scope:` to explicitly declare attribute scope
- `InitializerPatch` to apply default values for `final` instance attributes
- `memoize_default_value` helper to simplify accessor generation
- 100% RSpec coverage and branch coverage
- Steep RBS type signatures for public and internal API
- Full introspection via `.attributes`, `.attribute`, `.attribute_methods`, `.attribute_source`

### Removed

- `iattr`, `cattr`, `iattr_alias`, `cattr_alias`, and setter helpers (`*_setter`)
- Legacy inheritance hook logic and module-style patching

### Notes

This release consolidates and simplifies the attribute system into a modern, safer, and more flexible DSL. All existing functionality is preserved through the `cattri` interface.

This version introduces **breaking changes** to the DSL. Migration guide available in the README.

---

## [0.1.3] - 2025-04-22

### Added

- ✅ Support for `predicate: true` on both `iattr` and `cattr` — defines a `:name?` method returning `!!send(:name)`
- ✅ `iattr_alias` and `cattr_alias` — define alias methods that delegate to existing attributes (e.g., `:foo?` for `:foo`)
- Predicate methods inherit visibility from the original attribute and are excluded from introspection (`iattrs`, `cattrs`)
- Raised error when attempting to define an attribute ending in `?`, with guidance to use `predicate: true` or `*_alias`

## [0.1.2] - 2025-04-22

### Added

- Support for defining multiple attributes in a single call to `cattr` or `iattr`.
  - Example: `cattr :foo, :bar, default: 1`
  - Shared options apply to all attributes.
- Adds `cattr_setter` and `iattr_setter` for defining setters on attributes, useful when defining multiple attributes since ambiguous blocks are not allow.
  ```ruby
  class Config
    include Cattri
  
    cattr :a, :b               # new functionality, does not allow setter blocks.
                               # creates writers as def a=(val); @a = val; end
    
    cattr_setter :a do |val|   # redefines a= as def a=(val); val.to_s.downcase.to_sym; end
      val.to_s.downcase.to_sym
    end
  end
  ```
- Validation to prevent use of a block when defining multiple attributes.
  - Raises `Cattri::AmbiguousBlockError` if `&block` is passed with more than one attribute.

## [0.1.1] - 2025-04-22

### Added

- `Cattri::Context`: new class encapsulating all class-level and instance-level attribute metadata.
- `Cattri::Attribute`: formal representation of a defined attribute, with support for default values, coercion, and visibility.
- `Cattri::AttributeDefiner`: internal abstraction for building attributes and assigning behavior based on visibility and type.
- `Cattri::Visibility`: tracks current method visibility (`public`, `protected`, `private`) to ensure dynamically defined methods (e.g., via `cattr`, `iattr`) respect the active access scope during declaration.

### Changed

- Internal architecture now uses `Context` to manage attribute storage and duplication logic across inheritance chains.
- Class and instance attribute definitions (`cattr`, `iattr`) now delegate to `AttributeDefiner`, improving consistency and reducing duplication.
- Visibility handling is now centralized through `Cattri::Visibility`, which intercepts `public`, `protected`, and `private` to track and apply the current access level when defining methods.
- Subclass inheritance now copies attribute metadata and current values using a consistent, visibility-aware strategy.

### Removed

- Legacy handling of attribute hashes and manual copying in `inherited` hooks.
- Ad hoc attribute construction logic in `ClassAttributes` and `InstanceAttributes`.

### Improved

- Clear separation of concerns between metadata (`Attribute`), context (`Context`), and definition logic (`AttributeDefiner`).
- More robust error messages and consistent failure behavior when defining attributes with invalid configuration.

---

No breaking changes – the public DSL (cattr, iattr) remains identical to v0.1.0.

---

## [0.1.0] - 2025-04-17

- Initial release
