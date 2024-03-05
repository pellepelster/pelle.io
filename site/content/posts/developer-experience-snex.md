---
title: "SNippet EXtractor"
subtitle: Developer Experience
date: 2024-03-05T12:00:00+01:00
draft: false
---

If you are part of a platform team or develop libraries or SDKs that are used by other people, a small detail from my previous [post]({{< relref "/posts/developer-experience-do-file" >}}) of the developer experience [series](/tags/dx/) might have caught your eye.

> There may be a `README.MD` somewhere with information [...], but this information tends to get outdated very fast

This problem gets increasingly worse when you use your documentation to provide code samples that illustrate how to use the platform, the library or the SDK that you provide. 

Maintaining those code snippets is a tedious task, and they get outdated when the platform or library/SDK evolves. Also, it would be nice to be able to ensure, that the code in the documentation is always tested and guaranteed to run.  

<!--more-->

`snex` (**SN**ippet **EX**tractor) is a tool, that helps you to keep the code snippets inside your documentation always in sync with real code from your sources. It works line based on text files and iterates through all files inside of one or more folders, where it searches for snippet start- and end-markers and replaces all content between those markers with the referenced snippet.

Those markers are language agnostic, so you can embed them in a way that the source file is not corrupted by the markers, typically you want to choose comments for that,

e.g. for Java

```shell
// snippet[snippet1]
```

or inside of HTML

```shell
<!-- snippet[snippet1] -->
```

There are three types of markers available that must be opened and closed like HTML tags

* `snippet[${id}]` and `/snippet` define the beginning and end of a snippet that can be inserted somewhere else

* `insertSnippet[${id}]` and `/insertSnippet` define the bounds where the snipped with the id `${id}` will be inserted

* `insertFile[${file}]` and `/insertFile` define the bounds where the whole file `${file}` will be inserted


## Usage Example

Given then example files

**example/README.md**

```markdown
# Example 1

## Include snippet1

<!-- insertSnippet[snippet1] -->
<!-- /insertSnippet -->

## Include full file

<!-- insertFile[file1.go] -->
<!-- /insertFile -->
```

**example/snippets.go**
```go
package input

import "testing"

func TestcaseForCodeSnippet1(t *testing.T) {
	// snippet[snippet1]
	var lines = []string{"unit", "tested", "code"}
	for line := range lines {
		println(line)
	}
	//  /snippet
}
```

**example/file1.go**
```go
package input

func includeFullFile() {
	println("file1")
}
```

after running `snex` inside the `example` folder via

```shell
snex ./example
```

The `README.md` will look like this

**example/README.md**
````markdown
# Example 1

## Include snippet1

<!-- insertSnippet[snippet1] -->
```
	var lines = []string{"unit", "tested", "code"}
	for line := range lines {
		println(line)
	}
```

<!-- /insertSnippet -->

## Include full file

<!-- insertFile[file1.go] -->
```
package input

func includeFullFile() {
	println("file1")
}
```

<!-- /insertFile -->
````

`snex` will keep the original markers to ensure it can be re-run anytime on the documentation sources. This allows you to regularly test the example code e.g. as part of a test suite, ensuring the code in the documentation is always up-to-date. For usage information head over to [github.com/pellepelster/snex](https://github.com/pellepelster/snex)

## Template Support

`snex` has default replacement templates for different well-known files extensions. E.g. replacements inside a `.md` will automatically be surrounded by Markdown code block markers.

You can override the used template with

```shell
snex --template 'begin\n{{.Content}}\nend' ./
```

To show the list of default templates run

```shell
snex show-templates
```
