# Changelog

## Unreleased

### Added

- `ParsedString.parsedContents` for seeing exactly how the parse tree looks for a ParsedString.

### Changed

- `SyntaxTreeNode.path(to:)` now works when the `location == endIndex`. This used to be an invalid parameter. Now, it is valid and will get associated with the last child in the tree.
- Minor grammar adustments

### Fixed 

- Fixed bug where maintaining the `AttributesArray` could result in negative-length runs

## [0.9.1] - 2021-12-27

### Fixed

- There was a bug in the algorithm for traslating bounds between original content & up-to-date content in a piece table

## [0.9.0] - 2021-12-20

### Breaking change!

- `ParsedString.path(to:)` and `SyntaxTreeNode.path(to:)` are now throwing functions if given an index that is out-of-bounds.

## [0.8.0] - 2021-09-26

### Changed

- Got rid of the `key` parameter in `MarkupFormattingTextViewImageStorage`

## [0.7.3] - 2021-08-14

### Fixed

- Fixed memory leak of doubly-linked-list syntax nodes

## [0.7.2] - 2021-08-08

### Fixed

- Fixed crash when deleting all text

## [0.7.1] - 2021-06-28

### Changed

- Cleaned up warnings & tests

## [0.7.0] - 2021-06-22

### Changed

- `ParsedAttributedString.Settings` renamed to `ParsedAttributedString.Style`

### Added

- A built-in style for MiniMarkdown text, `MiniMarkdownGrammer.defaultEditingStyle()`
- A sample application to show TextMarkupKit in use

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
