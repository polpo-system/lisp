MODULE LispTest;  (** LispTest.Run: expressions evaluated by Lisp, their values compared; needs the desktop's display *)

IMPORT Texts, Lisp, Out := out;

VAR fails, checks: LONGINT;

PROCEDURE Check(what: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  INC(checks);
  IF ~ok THEN INC(fails); Out.String("FAIL "); Out.String(what); Out.Ln END
END Check;

(* the value of the expression e: the text Lisp writes for it *)
PROCEDURE Value(e: ARRAY OF CHAR; VAR v: ARRAY OF CHAR);
VAR T: Texts.Text; W: Texts.Writer; R: Texts.Reader; ch: CHAR; beg, i: LONGINT;
BEGIN
  NEW(T); Texts.Open(T, ""); Texts.OpenWriter(W); Texts.WriteString(W, e); Texts.Append(T, W.buf);
  beg := Lisp.Log.len; Lisp.EvalText(T, 0, T.len);
  Texts.OpenReader(R, Lisp.Log, beg); Texts.Read(R, ch); i := 0;
  WHILE ~R.eot & (ch # 0DX) & (i < LEN(v) - 1) DO v[i] := ch; INC(i); Texts.Read(R, ch) END;
  v[i] := 0X
END Value;

PROCEDURE Is(e, want: ARRAY OF CHAR);
VAR v: ARRAY 256 OF CHAR;
BEGIN
  Value(e, v); Check(e, v = want);
  IF v # want THEN Out.String("  got "); Out.String(v); Out.Ln END
END Is;

PROCEDURE Run*;
BEGIN
  fails := 0; checks := 0;
  Is("(add 1 2)", "3");
  Is("(sub 10 3 2)", "5");
  Is("(mul 12345678901234567890 98765432109876543210)", "1219326311370217952237463801111263526900");
  Is("(fact 30)", "265252859812191058636308480000000");
  Is("(car '(a b c))", "a");
  Is("(cdr '(a b c))", "(b c)");
  Is("(cons 'x '(y))", "(x y)");
  Is("(setq sq (lambda (x) (mul x x)))", "F[1]((mul #0 #0))");
  Is("(sq 25)", "625");
  Is("(lss 1 2)", "t");
  Is("(lss 2 1)", "nil");
  Is("(gcd 84 36)", "12");
  Out.String("LispTest: "); Out.Int(checks, 0); Out.String(" checks, "); Out.Int(fails, 0); Out.String(" failed"); Out.Ln
END Run;

END LispTest.
