# Simple Flake8 linter package

Find and display flake8 linting errors using `cmd-shift-8`(OSX) or
`ctrl-shift-8`(Linux/Wndows) in Atom.

There is currently a very nice linter plugin which many code linters hook into,
however I find it to be a bit too intrusive and distracting for daily use. This
flake8 package is simplified greatly and simply displays all flake8 errors in a
filterable list.

Clicking on any item in the list of errors will move your primary cursor to the
location of the error.

![preview](https://raw.github.com/induane/simple-flake8/master/preview.png)

https://github.com/atom/command-palette Was the primary visual inspiration for
this package and used it as the starting point for portions of the code base.

Other inspiration (and some code) has come from another linter application:
https://github.com/julozi/atom-flake8
