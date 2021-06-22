# Changelog

## [0.6.0] - 2021-06-21

### Changed

- Added `ParsedAttributedStringFormatter` and `AnyParsedAttributedStringFormatter` to control string formatting.

## [0.5.0] - 2021-06-21

### Added

- `MarkupFormattingTextView` for displaying and editing text with the formatting determined by a `ParsedAttributedString`

## [0.4.1] - 2021-06-20  Oops

I left old versions of files in the 0.4.0 release. Clean that up.

## [0.4.0] - 2021-06-20  Happy Father's Day!

Pretty substantial revisions. This now contains the code that has been developed and tested as part of Grail Diary.

## [0.3.1] - 2020-06-03

### Added

* Added `PieceTable.sliceCount`

## [0.3.0] - 2020-05-12

### Fixed

* Performance! Memoizing the string in the text storage is a big boost.

## [0.2.0] - 2020-05-12

### Fixed

* Fixed bug that manifested in crashes while typing. The underlying problem is I was mutating nodes that "belonged" to result objects with no way to update the enclosing result. The fix was to make a copy of the node before mutating. I might want to make Node be a struct but I'm not ready to do that investigation yet.

## [0.1.0] - 2020-05-10

### Added

* `IncrementalParsingTextStorage.rawText` to get text without formatting replacements applied.

## [0.0.1] - 2020-05-07

The initial "MVP" release! Provides an implementation of NSTextStorage that does incremental parsing of its contents and uses the resulting parse tree to determine the text attributes. E.g., it can provide syntax highlighting that changes as you type.
