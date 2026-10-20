Lisp (Robert Griesemer, ETH 1991) - a small Lisp with whole numbers of any size

  Lisp.Open ~      a viewer Log.Lisp: type an expression and end it with \ to evaluate it;
                   the value is written below it
  Lisp.Eval        (in the menu) evaluates the selected expressions
  Lisp.Reset       forgets every definition

Try these in Log.Lisp (each ended with \), or select them and click Lisp.Eval:

  (add 1 2 3)
  (fact 100)
  (mul 12345678901234567890 98765432109876543210)
  (setq sq (lambda (x) (mul x x)))
  (sq 123456789)
  (car '(a b c))   (cdr '(a b c))   (cons 'x '(y z))
  (cond ((lss 2 1) 'smaller) (t 'bigger))
  (time (fact 1000))      the milliseconds it took

The built-in functions:
  quote car cdr cons set setq           lists and names
  add sub mul div mod gcd fact          arithmetic on whole numbers
  eq eql lss leq and or not atom        tests: t or nil
  lambda cond eval names time           functions, conditions, the defined names, timing
  read write writeLn                    reading and writing expressions
Comments are written in braces: { like this }. Names are made of letters and digits only;
an expression Lisp cannot read stops it with a trap (HALT 99), as in the original.
