# ``TextMarkupKit``

TextMarkupKit makes it easy to add *format as you type* capabilities to any iOS application. 

## Overview

Many iOS applications give you the ability to write plain text in a `UITextView` and format that text based upon simple rules. TextMarkupKit makes it easy to add "format as you type" capabilities to any iOS application. 


It consists of several interrelated components:

1. One set of components let you write a [Parsing Expression Grammar](https://en.wikipedia.org/wiki/Parsing_expression_grammar) to define how to parse the user's input. Because writing grammars is hard, TextMarkupKit lets you design "composable grammars." If there is an existing grammar that *almost* provides what you want, you can extend it with additional rules rather than write a new grammar from scratch. TextMarkupKit provides a grammar for a subset of Markdown syntax called *MiniMarkdown*.
2. An implementation of Dubroy & Warth's [Incremental Packrat Parsing](https://ohmlang.github.io/pubs/sle2017/incremental-packrat-parsing.pdf) algorithm to efficiently re-parse text content as the user types in the `UITextView`.
3. A system to format an `NSAttributedString` based upon the parse tree for its ``ParsedAttributedString/rawString`` contents. TextMarkupKit's formatting support was designed around the needs of lightweight *human markup languages* like Markdown instead of syntax highlighting of programming languages. In addition to changing the attributes associated with text, TextMarkupKit's formatting rules let you transform the displayed text itself. For example, you may choose to change a space to a tab when formatting a list, or not show the special formatting delimiters in some modes, or replace an image markup sequence with an actual image attachment. TextMarkupKit supports all of these modes.
4. A way to efficiently integrate the formatted `NSAttributedString` with TextKit so it can be used with a `UITextView`.


## Topics

### Parsing

- ``ParsingRule``
- ``ParsingResult``
- ``PackratGrammar``
- ``MemoizationTable``
- ``SyntaxTreeNode``
- ``SyntaxTreeNodeType``

### Grammar building blocks

- ``DotRule``
- ``Characters``
- ``Literal``
- ``InOrder``
- ``Choice``
- ``AssertionRule``
- ``NotAssertionRule``
- ``RangeRule``

### Text formatting rules

- ``ParsedAttributedStringFormatter``
- ``AnyParsedAttributedStringFormatter``

### Mini-Markdown

- ``MiniMarkdownGrammar``
- ``HeaderFormatter``

### Text storage and editing

- ``PieceTable``
- ``PieceTableString``
- ``ParsedString``
- ``ParsedAttributedString``

