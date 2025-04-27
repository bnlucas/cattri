# Changelog

## [0.2.0] - 2025-04-26

### Major Changes

- **Refactored core class: `Cattri::Context`**
  - Centralized method and ivar management for attribute definitions.
  - Handles scoping (class vs. instance), visibility, and method tracking.
  - Ensures safe redefinition and clean inheritance behavior.

- **New core class: `Cattri::AttributeRegistry`**
  - Tracks attributes cleanly per class/module.
  - Provides attribute lookup, duplication, redefinition, and mutation safety.

- **New core class: `Cattri::AttributeCompiler`** (formerly `AttributeDefiner`)
  - Compiles attributes into methods.
  - Supports clean separation for class-level and instance-level method generation.
  - Enforces attribute validation rules consistently.

- **New core module: `Cattri::DeferredAttributes`**
  - Defers attribute definitions when defining attributes in mixin modules.
  ```ruby
  module Options
    include Cattri
  
    iattr :enabled
    iattr :config, default: {}
  end
  
  class MyClass
    include Options
    # iattrs from Options are defined on include
  end
  ```

- **Attribute immutability support**
  - Added `:final` option to attributes.
    - Class attributes: `final` enforces `readonly: true`.
    - Instance attributes: `final` enforces `writer: false`.
    - `final` attributes cannot be written to and cannot be redefined or have new setters defined.
    - `readonly` attributes cannot be written to, but can be redefined and have new setters defined.
  - New errors:
    - `Cattri::FinalizedAttributeError`
    - `Cattri::ReadonlyAttributeError`

- **Inheritance refactor**
  - Attribute metadata and values are now duplicated and recompiled via `Context`.
  - Prevents inherited attributes from accidentally sharing state or visibility.
  - Fixes subtle bugs where subclassing could lead to accidental method conflicts.

### New API Helpers

- `final_class_attribute(name, value, **options)`
  - `final_cattr(name, value, **options)`
- `final_instance_attribute(name, value, **options)`
  - `final_iattr(name, value, **options)`
- `readonly_class_attribute(name, value, **options)`
  - `readonly_cattr(name, value, **options)`
- `readonly_instance_attribute(name, value, **options)`
  - `readonly_iattr(name, value, **options)`

These enforce `final` and/or `readonly` behavior and require a default value.

### Behavior Changes

- `readonly` and `final` attributes must now provide a default value at definition time.
- Redefining methods from inherited attributes no longer fails improperly — method checks are scoped locally.
- Writers for `readonly` or `final` attributes are now explicitly blocked with clear errors.
- Default values for attributes are always normalized into procs internally (`default.call` pattern).

### Testing and Coverage

- Added full RSpec specs for:
  - `Context`
  - `AttributeRegistry`
  - `AttributeCompiler`
  - Error coverage (including new errors)
- Branch coverage for all critical paths (including `final` and `readonly` guards).
- Clean separation of integration and unit specs.

### Internal Improvements

- `normalize_target` now safely handles singleton classes without polluting ancestry.
- All method generation uses `class_eval` consistently to maintain correct visibility scopes.
- Method overwrites are tracked at the attribute level to avoid double-definitions.
- Cleaner error messages when trying to overwrite protected methods without `force: true`.

### Introspection helper

- Added the `with_cattri_introspection` method to easily enable introspection as needed.
  ```ruby
  class Config
    include Cattri
  
    with_cattri_introspection
  end
  ```

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
