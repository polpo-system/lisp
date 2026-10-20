# lisp

Oberon Lisp for the desktop of [polpo](https://github.com/polpo-system/polpo): a small Lisp
interpreter by Robert Griesemer, written at ETH Zurich in 1991 for Oberon V4. Its numbers are whole
numbers of any size, so `(fact 100)` gives all 158 digits.

```
portia.Install lisp
```

## Using

    Lisp.Open ~     a viewer Log.Lisp: type an expression, end it with \ and its value is
                    written below it
    Lisp.Eval       (in the menu) evaluates the selected expressions
    Lisp.Reset      forgets every definition

For example:

    (setq sq (lambda (x) (mul x x)))
    (sq 123456789)
    (fact 30)

`tools/Lisp.Tool` lists the built-in functions and has more examples.

## What is here

    src/Integers.Mod      whole numbers of any size (OOC)
    src/Lisp.Mod          the interpreter
    tools/Lisp.Tool
    test/LispTest.Mod

The first commit has both sources unchanged: Lisp.Mod as it was in 1993 (from an ETH Oberon
archive), Integers.Mod from OOC 1.5.9, since the Integers module of Oberon V4 that Lisp was written
for is not at hand and OOC's has the same procedures. The later commits make them work in polpo:
Integers without the two procedures that need OOC's binary files (they compile only on x86), a
product of two digits widened before it overflowed, and Lisp in the text viewers of polpo's
desktop instead of Oberon V4's Write editor. Lisp.EvalText evaluates the expressions of any text,
which the test uses.

## Tests

    LispTest.Run      12 checks: expressions evaluated and their values compared; it needs the
                      desktop's display

The license is GPL-3 (`LICENSE`). Lisp comes from ETH Oberon, whose license (`LICENSE.ETH`) asks to
keep its copyright notice and conditions, which `LICENSE.ETH` does. Integers.Mod is under the GNU
Lesser General Public License, version 2 or later (`LICENSE.LGPL`).
