# Changelog

## [0.1.0] - 2020-05-10

### Added

* `IncrementalParsingTextStorage.rawText` to get text without formatting replacements applied.

## [0.0.1] - 2020-05-07

The initial "MVP" release! Provides an implementation of NSTextStorage that does incremental parsing of its contents and uses the resulting parse tree to determine the text attributes. E.g., it can provide syntax highlighting that changes as you type.
