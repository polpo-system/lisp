MODULE Lisp;

	IMPORT Display, Texts, TextFrames, WriteFrames, MenuViewers, Oberon, Integers;

	CONST
		Version = "Oberon Lisp - gri 24 Jun 91 / 19 Mar 93";
		Menu = "System.Close  System.Copy  System.Grow  Write.Store  Write.Locate  !Lisp.Reset  Lisp.Eval  ";
		Char = 0; Name = 1; Int = 2; (* scanner symbols *)
		MaxArgs = 6; Tick = 300;

	TYPE
		List = POINTER TO Desc;
		Desc = RECORD END;
		
		Pair = POINTER TO PairDesc;
		PairDesc = RECORD(Desc)
			car, cdr: List
		END;
		
		Number = POINTER TO NumberDesc;
		NumberDesc = RECORD(Desc)
			val: Integers.Integer
		END;
		
		Symbol = POINTER TO SymbolDesc;
		SymbolDesc = RECORD(Desc)
			left, right: Symbol;
			name: ARRAY 32 OF CHAR;
			bound: List
		END;
		
		Local = POINTER TO LocalDesc;
		LocalDesc = RECORD(Desc);
			no: INTEGER
		END;
		
		Function = PROCEDURE (x: List): List;
		BuiltIn = POINTER TO BuiltInDesc;
		BuiltInDesc = RECORD(Desc);
			fun: Function
		END;
		
		Lambda = POINTER TO LambdaDesc;
		LambdaDesc = RECORD(Desc);
			nofArgs: INTEGER; ext: BOOLEAN;
			fun: List
		END;
		
		Stack = POINTER TO StackSeg;
		StackSeg = RECORD
			arg: ARRAY MaxArgs OF List;
			prev: Stack
		END;

		Scanner = RECORD (Texts.Reader)
			class: INTEGER;
			next: CHAR;
			c: CHAR;
			s: ARRAY 32 OF CHAR;
			i: Integers.Integer
		END;

	VAR
		W: Texts.Writer;
		Log: Texts.Text;
		S: Scanner;
		root, t, quot: Symbol; (* special symbols *)
		subst: ARRAY MaxArgs OF Local; (* parameter substitutes *)
		stack: Stack; (* lambda evaluation stack *)


(* symbol management *)

	PROCEDURE Insert(name: ARRAY OF CHAR): Symbol;
		VAR p, q: Symbol;
	BEGIN p := NIL; q := root;
		WHILE q # NIL DO p := q;
			IF name < q.name THEN q := q.left
			ELSIF name > q.name THEN q := q.right
			ELSE (* found *) RETURN q
			END
		END;
		NEW(q); q.left := NIL; q.right := NIL; COPY(name, q.name); q.bound := NIL;
		IF p = NIL THEN root := q
		ELSIF name < p.name THEN p.left := q
		ELSE p.right := q
		END;
		RETURN q
	END Insert;


(* input *)

	PROCEDURE OpenScanner (VAR S: Scanner; text: Texts.Text; pos: LONGINT);
	BEGIN Texts.OpenReader(S, text, pos); Texts.Read(S, S.next)
	END OpenScanner;

	PROCEDURE Scan (VAR S: Scanner);
		VAR ch: CHAR; i: INTEGER; dig: ARRAY 1024 OF CHAR;
	BEGIN ch := S.next;
		WHILE ~S.eot & (ch <= " ") DO Texts.Read(S, ch) END;
		IF ("A" <= CAP(ch)) & (CAP(ch) <= "Z") THEN i := 0;
			REPEAT S.s[i] := ch; INC(i); Texts.Read(S, ch)
			UNTIL (ch < "0") OR ("9" < ch) & (CAP(ch) < "A") OR ("Z" < CAP(ch)) OR (i = LEN(S.s)-1);
			S.s[i] := 0X; S.class := Name
		ELSIF ch = "{" THEN
			REPEAT Texts.Read(S, ch) UNTIL S.eot OR (ch = "}");
			Texts.Read(S, S.next); Scan(S); ch := S.next
		ELSE
			IF ch = "-" THEN dig[0] := "-"; i := 1; Texts.Read(S, ch) ELSE i := 0 END;
			IF ("0" <= ch) & (ch <= "9") THEN
				REPEAT dig[i] := ch; INC(i); Texts.Read(S, ch)
				UNTIL (ch < "0") OR ("9" < ch) OR (i = LEN(dig)-1);
				dig[i] := 0X; Integers.ConvertFromString(dig, S.i); S.class := Int
			ELSE
				IF i = 1 THEN S.c := "-" ELSE S.c := ch; Texts.Read(S, ch) END;
				S.class := Char
			END
		END;
		S.next := ch
	END Scan;

	PROCEDURE read (x: List): List;
		VAR p, q: Pair; n: Number; pos: LONGINT;
	BEGIN
		IF x = NIL THEN
			IF (S.class = Char) & (S.c = "'") THEN Scan(S);
				NEW(p); p.car := read(NIL); p.cdr := NIL;
				NEW(q); q.car := quot; q.cdr := p; x := q
			ELSIF (S.class = Char) & (S.c = "(") THEN Scan(S);
				IF (S.class # Char) OR (S.c # ".") & (S.c # ")") THEN
					NEW(p); p.car := read(NIL); p.cdr := NIL; x := p
				END;
				WHILE (S.class # Char) OR (S.c # ".") & (S.c # ")") DO
					NEW(q); q.car := read(NIL); q.cdr := NIL; p.cdr := q; p := q
				END;
				IF (S.class = Char) & (S.c = ".") THEN Scan(S); p.cdr := read(NIL) END;
				IF (S.class = Char) & (S.c = ")") THEN Scan(S) ELSE pos := Texts.Pos(S)-1; HALT(99) END
			ELSIF S.class = Name THEN
				IF S.s # "nil" THEN x := Insert(S.s) END;
				Scan(S)
			ELSIF S.class = Int THEN NEW(n); n.val := S.i; x := n; Scan(S)
			ELSE pos := Texts.Pos(S)-1; HALT(99)
			END;
			RETURN x
		END
	END read;


(* output *)

	PROCEDURE write (x: List);
		VAR p: Pair; blank: BOOLEAN;
	BEGIN
		IF x = NIL THEN Texts.WriteString(W, "nil")
		ELSIF x IS Pair THEN
			Texts.Write(W, "("); blank := FALSE;
			REPEAT p := x(Pair); x := p.cdr;
				IF blank THEN Texts.Write(W, " ") END;
				write(p.car); blank := TRUE
			UNTIL (x = NIL) OR ~(x IS Pair);
			IF x # NIL THEN Texts.WriteString(W, " . "); write(x) END;
			Texts.Write(W, ")")
		ELSIF x IS Number THEN Integers.Write(W, x(Number).val)
		ELSIF x IS Symbol THEN Texts.WriteString(W, x(Symbol).name)
		ELSIF x IS Local THEN Texts.Write(W, "#"); Texts.WriteInt(W, x(Local).no, 0)
		ELSIF x IS Lambda THEN
			Texts.WriteString(W, "F["); Texts.WriteInt(W, x(Lambda).nofArgs, 0); Texts.Write(W, "]"); write(x(Lambda).fun)
		ELSE Texts.WriteString(W, "[builtIn]")
		END
	END write;


(* interpreter primitives *)

	PROCEDURE eval (x: List): List;
		VAR p: Pair; f, h: List; s: Stack; i, n: INTEGER;
	BEGIN
		IF x = NIL THEN RETURN x
		ELSIF x IS Symbol THEN RETURN x(Symbol).bound
		ELSIF x IS Local THEN RETURN stack.arg[x(Local).no]
		ELSIF x IS Pair THEN p := x(Pair); x := p.cdr; f := eval(p.car);
			IF f IS BuiltIn THEN RETURN f(BuiltIn).fun(x)
			ELSE
				WITH f: Lambda DO NEW(s); i := 0; n := f.nofArgs;
					WHILE i < n DO p := x(Pair); x := p.cdr; s.arg[i] := eval(p.car); INC(i) END;
					IF f.ext THEN s.arg[i] := x; x := NIL END;
					IF x = NIL THEN s.prev := stack; stack := s; x := f.fun; h := NIL;
						WHILE x # NIL DO p := x(Pair); x := p.cdr; h := eval(p.car) END;
						stack := stack.prev; RETURN h
					END
				END
			END
		ELSE RETURN x
		END
	END eval;
	
	PROCEDURE eval1 (x: List): List;
	BEGIN
		WITH x: Pair DO
			IF x.cdr = NIL THEN RETURN eval(eval(x.car)) END
		END
	END eval1;
	
	PROCEDURE write1 (x: List): List;
		VAR h: List;
	BEGIN
		WITH x: Pair DO
			IF x.cdr = NIL THEN h := eval(x.car); write(h); RETURN h END
		END
	END write1;

	PROCEDURE writeLn (x: List): List;
	BEGIN IF x = NIL THEN Texts.WriteLn(W); Texts.Append(Log, W.buf); RETURN NIL END
	END writeLn;

	PROCEDURE quote (x: List): List;
		VAR p: Pair;
	BEGIN
		WITH x: Pair DO
			IF x.cdr = NIL THEN RETURN x.car END
		END
	END quote;

	PROCEDURE time (x: List): List;
		VAR h: List; n: Number; time: LONGINT;
	BEGIN
		WITH x: Pair DO
			IF x.cdr = NIL THEN NEW(n);
				time := Oberon.Time(); h := eval(x.car); n.val := Integers.Long((Oberon.Time() - time) * 1000 DIV Tick); RETURN n
			END
		END
	END time;
	
	PROCEDURE car (x: List): List;
		VAR h: List;
	BEGIN
		WITH x: Pair DO
			IF x.cdr = NIL THEN h := eval(x.car); RETURN h(Pair).car END
		END
	END car;
	
	PROCEDURE cdr (x: List): List;
		VAR h: List;
	BEGIN
		WITH x: Pair DO
			IF x.cdr = NIL THEN h := eval(x.car); RETURN h(Pair).cdr END
		END
	END cdr;
	
	PROCEDURE cons (x: List): List;
		VAR y: List; p: Pair;
	BEGIN
		WITH x: Pair DO y := x.cdr;
			WITH y: Pair DO
				IF y.cdr = NIL THEN NEW(p); p.car := eval(x.car); p.cdr := eval(y.car); RETURN p END
			END
		END
	END cons;

	PROCEDURE set (x: List): List;
		VAR y, a, b: List;
	BEGIN
		WITH x: Pair DO y := x.cdr;
			WITH y: Pair DO
				IF y.cdr = NIL THEN a := eval(x.car); b := eval(y.car);
					IF a IS Symbol THEN a(Symbol).bound := b
					ELSE stack.arg[a(Local).no] := b
					END;
					RETURN b
				END
			END
		END
	END set;
	
	PROCEDURE setq (x: List): List;
		VAR y, a, b: List;
	BEGIN
		WITH x: Pair DO y := x.cdr;
			WITH y: Pair DO
				IF y.cdr = NIL THEN a := x.car; b := eval(y.car);
					IF a IS Symbol THEN a(Symbol).bound := b
					ELSE stack.arg[a(Local).no] := b
					END;
					RETURN b
				END
			END
		END
	END setq;
	
	PROCEDURE F (x: List; f: PROCEDURE (x, y: Integers.Integer): Integers.Integer): List;
		VAR v: Integers.Integer; p: Pair; h: List; n: Number;
	BEGIN p := x(Pair); x := p.cdr; h := eval(p.car); v := h(Number).val;
		REPEAT p := x(Pair); x := p.cdr; h := eval(p.car); v := f(v, h(Number).val) UNTIL x = NIL;
		NEW(n); n.val := v; RETURN n
	END F;

	PROCEDURE add (x: List): List;
	BEGIN RETURN F(x, Integers.Sum)
	END add;

	PROCEDURE sub (x: List): List;
	BEGIN RETURN F(x, Integers.Difference)
	END sub;

	PROCEDURE mul (x: List): List;
	BEGIN RETURN F(x, Integers.Product)
	END mul;

	PROCEDURE div (x: List): List;
	BEGIN RETURN F(x, Integers.Quotient)
	END div;
	
	PROCEDURE mod (x: List): List;
	BEGIN RETURN F(x, Integers.Remainder)
	END mod;
	
	PROCEDURE gcd (x: List): List;
	BEGIN RETURN F(x, Integers.GCD)
	END gcd;

	PROCEDURE fact (x: List): List;
		VAR h: List; n: Number;

		PROCEDURE Mul (a, b: LONGINT): Integers.Integer;
			VAR m: LONGINT;
		BEGIN
			IF a < b THEN m := (a + b) DIV 2; RETURN Integers.Product(Mul(a, m), Mul(m+1, b))
			ELSE RETURN Integers.Long(a)
			END
		END Mul;

	BEGIN
		WITH x: Pair DO
			IF x.cdr = NIL THEN h := eval(x.car); NEW(n); n.val := Mul(1, Integers.Short(h(Number).val)); RETURN n END
		END
	END fact;

	PROCEDURE names (x: List): List;
		PROCEDURE Traverse(s: Symbol; VAR x: List);
			VAR h: Pair;
		BEGIN IF s # NIL THEN Traverse(s.right, x); NEW(h); h.car := s; h.cdr := x; x := h; Traverse(s.left, x) END 
		END Traverse;
	BEGIN IF x = NIL THEN Traverse(root, x); RETURN x END
	END names;
	
	PROCEDURE lambda (x: List): List;
		VAR
			q: List; p: Pair; f: Lambda;
			par: ARRAY MaxArgs OF Symbol;
			n: INTEGER;
			
		PROCEDURE Subst (x: List): List;
			VAR p, q: Pair; s: Symbol; i: INTEGER;
		BEGIN
			IF x # NIL THEN
				IF x IS Pair THEN q := x(Pair); NEW(p); p.car := Subst(q.car); p.cdr := Subst(q.cdr); x := p
				ELSIF x IS Symbol THEN s := x(Symbol); i := 0;
					WHILE (i < n) & (s # par[i]) DO INC(i) END;
					IF i < n THEN x := subst[i] END
				END
			END;
			RETURN x
		END Subst;

	BEGIN q := x(Pair).car; n := 0;
		WHILE (q # NIL) & (q IS Pair) DO p := q(Pair); q := p.cdr; par[n] := p.car(Symbol); INC(n) END;
		NEW(f); f.nofArgs := n;
		IF q # NIL THEN par[n] := q(Symbol); INC(n); f.ext := TRUE ELSE f.ext := FALSE END;
		f.fun := Subst(x(Pair).cdr);
		RETURN f
	END lambda;
	
	PROCEDURE eq (x: List): List;
		VAR p: Pair; h: List;
	BEGIN p := x(Pair); x := p.cdr; h := eval(p.car);
		REPEAT p := x(Pair); x := p.cdr;
			IF h # eval(p.car) THEN RETURN NIL END
		UNTIL x = NIL;
		RETURN t
	END eq;
	
	PROCEDURE eql (x: List): List;
		VAR p: Pair; h: List;
		
		PROCEDURE TheSame(x, y: List): BOOLEAN;
			VAR p, q: Pair;
		BEGIN
			IF (x # NIL) & (y # NIL) THEN
				IF (x IS Number) & (y IS Number) THEN RETURN Integers.Compare(x(Number).val, y(Number).val) = 0
				ELSIF (x IS Pair) & (y IS Pair) THEN p := x(Pair); q := y(Pair); RETURN TheSame(p.car, q.car) & TheSame(p.cdr, q.cdr)
				END
			END;
			RETURN x = y
		END TheSame;
		
	BEGIN p := x(Pair); x := p.cdr; h := eval(p.car);
		REPEAT p := x(Pair); x := p.cdr;
			IF ~TheSame(h, eval(p.car)) THEN RETURN NIL END
		UNTIL x = NIL;
		RETURN t
	END eql;
	
	PROCEDURE lss (x: List): List;
		VAR p: Pair; h: List; v, w: Integers.Integer;
	BEGIN p := x(Pair); x := p.cdr; h := eval(p.car); v := h(Number).val;
		REPEAT p := x(Pair); x := p.cdr; h := eval(p.car); w := h(Number).val;
			IF Integers.Compare(v, w) >= 0 THEN RETURN NIL END;
			v := w
		UNTIL x = NIL;
		RETURN t
	END lss;
	
	PROCEDURE leq (x: List): List;
		VAR p: Pair; h: List; v, w: Integers.Integer;
	BEGIN p := x(Pair); x := p.cdr; h := eval(p.car); v := h(Number).val;
		REPEAT p := x(Pair); x := p.cdr; h := eval(p.car); w := h(Number).val;
			IF Integers.Compare(v, w) > 0 THEN RETURN NIL END;
			v := w
		UNTIL x = NIL;
		RETURN t
	END leq;
	
	PROCEDURE and (x: List): List;
		VAR p: Pair;
	BEGIN
		REPEAT p := x(Pair); x := p.cdr;
			IF eval(p.car) = NIL THEN RETURN NIL END
		UNTIL x = NIL;
		RETURN t
	END and;
	
	PROCEDURE or (x: List): List;
		VAR p: Pair;
	BEGIN
		REPEAT p := x(Pair); x := p.cdr;
			IF eval(p.car) # NIL THEN RETURN t END
		UNTIL x = NIL;
		RETURN NIL
	END or;
	
	PROCEDURE not (x: List): List;
	BEGIN
		WITH x: Pair DO
			IF x.cdr = NIL THEN
				IF eval(x.car) = NIL THEN RETURN t ELSE RETURN NIL END
			END
		END
	END not;

	PROCEDURE cond (x: List): List;
		VAR y, h: List; p: Pair;
	BEGIN h := NIL;
		REPEAT p := x(Pair); x := p.cdr; y := p.car;
			IF y # NIL THEN p := y(Pair); y := p.cdr; h := eval(p.car);
				IF h # NIL THEN (* first t condition *) x := NIL;
					WHILE y # NIL DO p := y(Pair); y := p.cdr; h := eval(p.car) END
				END
			END
		UNTIL x = NIL;
		RETURN h
	END cond;

	PROCEDURE atom (x: List): List;
		VAR h: List;
	BEGIN
		WITH x: Pair DO
			IF x.cdr = NIL THEN h := eval(x.car);
				IF (h = NIL) OR ~(h IS Pair) THEN RETURN t ELSE RETURN NIL END
			END
		END
	END atom;
	
	PROCEDURE Eval*;
		VAR text: Texts.Text; beg, end, time: LONGINT; x: List;
	BEGIN
		Oberon.GetSelection(text, beg, end, time);
		IF time >= 0 THEN OpenScanner(S, text, beg); Scan(S); stack := NIL;
			REPEAT write(eval(read(NIL))); x := writeLn(NIL) UNTIL Texts.Pos(S) >= end
		END;
		Oberon.Collect(0)
	END Eval;
	
	PROCEDURE Handle (F: Display.Frame; VAR msg: Display.FrameMsg);
		VAR org: LONGINT; x: List;
	BEGIN
		WITH F: WriteFrames.Frame DO
			IF msg IS Oberon.InputMsg THEN
				WITH msg: Oberon.InputMsg DO
					IF F.hasCar & (msg.id = Oberon.consume) & (msg.ch = "\") THEN
						msg.ch := 0DX; org := F.carLoc.org; WriteFrames.Handle(F, msg);
						OpenScanner(S, F.text, org); Scan(S); stack := NIL;
						write(eval(read(NIL))); x := writeLn(NIL); Oberon.Collect(0);
						IF WriteFrames.Pos(F, F.X+F.W, F.Y) < F.text.len THEN WriteFrames.Show(F, org) END;
						WriteFrames.SetCaret(F, F.text.len);
						RETURN
					END
				END
			END
		END;
		WriteFrames.Handle(F, msg)		
	END Handle;
	
	PROCEDURE Open*;
		VAR V: MenuViewers.Viewer; x, y: INTEGER;
	BEGIN
		Oberon.AllocateUserViewer(Oberon.Mouse.X, x, y);
		V := MenuViewers.New(
			TextFrames.NewMenu("Log.Lisp", Menu),
			WriteFrames.NewText(Log, 0),
			TextFrames.menuH, x, y);
		V.dsc.next.handle := Handle
	END Open;
	

(* initialization *)

	PROCEDURE Intrinsic (name: ARRAY OF CHAR; fun: Function);
		VAR b: BuiltIn; s: Symbol;
	BEGIN NEW(b); b.fun := fun; s := Insert(name); s.bound := b
	END Intrinsic;
	
	PROCEDURE Reset*;
		VAR i: INTEGER; q: Local; name: ARRAY 2 OF CHAR;
	BEGIN i := 0;
		WHILE i < MaxArgs DO NEW(q); q.no := i; subst[i] := q; INC(i) END;
	(* intrinsic symbols *)
		NEW(root);
		name[0] := "t"; name[1] := 0X; t := Insert(name); t.bound := t;
	(* intrinsic functions *)
		Intrinsic("quote", quote); quot := Insert("quote");
		Intrinsic("car", car);
		Intrinsic("cdr", cdr);
		Intrinsic("cons", cons);
		Intrinsic("set", set);
		Intrinsic("setq", setq);
		Intrinsic("add", add);
		Intrinsic("sub", sub);
		Intrinsic("mul", mul);
		Intrinsic("div", div);
		Intrinsic("mod", mod);
		Intrinsic("gcd", gcd);
		Intrinsic("fact", fact);
		Intrinsic("names", names);
		Intrinsic("lambda", lambda);
		Intrinsic("eq", eq);
		Intrinsic("eql", eql);
		Intrinsic("lss", lss);
		Intrinsic("leq", leq);
		Intrinsic("and", and);
		Intrinsic("or", or);
		Intrinsic("not", not);
		Intrinsic("atom", atom);
		Intrinsic("eval", eval1);
		Intrinsic("time", time);
		Intrinsic("cond", cond);
		Intrinsic("read", read);
		Intrinsic("write", write1);
		Intrinsic("writeLn", writeLn);
		Texts.Delete(Log, 0, Log.len)
	END Reset;

BEGIN Texts.OpenWriter(W);
	Texts.WriteString(W, Version); Texts.WriteLn(W);
	Texts.Append(Oberon.Log, W.buf);
	Log := WriteFrames.Text("");
	Reset
END Lisp.