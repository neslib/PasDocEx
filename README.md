# PasDocEx

Hacked on extensions to the excellent [PasDoc](http://pasdoc.sipsolutions.net/) documentation tool.

It supports some additional syntax for writing documentation, and outputs slightly different HTML.

## HTML Tags

In addition to PasDoc's formatting tags (like `@bold`), you can use a couple of supported HTML tags (like `<b>`):

| HTML Tag              | PasDoc equivalent |
|-----------------------|-------------------|
| `<b>..</b>`           | `@bold(..)`       |
| `<i>..</i>`           | `@italic(..)`     |
| `<source>..</source>` | `@longcode(..)`   |
| `<code>..</code>`     | `@code(..)`       |
| `<tt>..</tt>`         | `@code(..)`       |
| `<br>`                | `@br`             |

## Unordered Lists

In addition to PasDoc's `@unorderedList` and friends, you can write unordered lists like this:

\* Item 1
\* Item 2
\* Item 3
\* etc...

## Sections

There is support for sections as an alternative way to document parameters, return values, exceptions and see-also links. A section start with a new line containing a single word followed by a colon. The following sections are supported.

### Parameters:

An alternative to using `@param` to document parameters. A `Parameters:` section may look like this:

```
Parameters:
  Foo: description of the Foo parameter
  spanning multiple lines.
  Bar: description of the Bar parameter
  Baz: description of the Baz parameter
    spanning multiple: lines.
```

Notes:
* The individual parameters may be indented, but that is not required.
* A parameter description may span multiple lines. Additional lines may use an addition indent, but that is not required.
* The section is terminated when a blank line or the end of the string is encountered or when another section is started.

### Return: or Returns:

An alternative to using `@return` to document the return value. For example:

```
Returns:
  The answer to life, the universe and everything
```

### Raises:

An alternative to using `@raises` to document exceptions. For example:

```
Raises:
  EInvalidOperation if the Question parameter does not have value 42.
```
### SeeAlso:

An alternative to using `@seealso` to document relevant links. For example:

```
SeeAlso:
  TStringList, TList.Add,
  TList.Clear clearing a list, TInterfaceList
```

Multiple "see also" links may be separated by commas and/or new lines. A link may be followed by a space and link text. In that case, the link text will be used as the text for the hyperlink.

## Generated Output Differences

PasDocEx generates slightly different HTML(Help) output than PasDoc. The most notable differences are:
* Overloaded methods are grouped together in table of contents.
* Overloaded methods are grouped together in the documentation in case an overloaded version does not provide its own documentation.
* Outputs the sections for parameters, return values and exceptions differently.