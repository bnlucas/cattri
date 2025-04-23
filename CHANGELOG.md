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
