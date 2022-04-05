  $ PATH=$HOME/go/bin:$PATH
  $ run() { 
  >   janet "$TESTDIR/main.janet" "$@"
  > }

Basic stuff works:

  $ run <<EOF
  > 1 2 3 + 4 5 6
  > EOF
  1 2 3 + 4 5 6
  #= 5 7 9

Multiple outputs:

  $ run <<EOF
  > 1 2 3 + 4 5 6
  > 2 * 1 2 3
  > EOF
  1 2 3 + 4 5 6
  #= 5 7 9
  2 * 1 2 3
  #= 2 4 6

Verbose assignment vs silent assignment:

  $ run <<EOF
  > x = 1 2 3
  > y = x
  > #=
  > z = x + y
  > EOF
  x = 1 2 3
  y = x
  #= 1 2 3
  z = x + y

Errors show up above the lines with errors:

  $ run <<EOF
  > x = 1 2 3
  > z = x + y
  > EOF
  x = 1 2 3
  #! undefined variable "y"
  z = x + y

Output lines are not rewritten following an error:

  $ run <<EOF
  > x = 1 2 3
  > z = x + y
  > x
  > #= this is not correct
  > EOF
  x = 1 2 3
  #! undefined variable "y"
  z = x + y
  x
  #! unreachable
  #= this is not correct

Error lines are removed after an error is fixed:

  $ run <<EOF
  > x = 1 2 3
  > #! undefined variable "y"
  > z = x + x
  > x
  > #! unreachable
  > #= this is not correct
  > EOF
  x = 1 2 3
  z = x + x
  x
  #= 1 2 3

Multi-line definitions work:

  $ run <<EOF
  > op inc x =
  > x + 1
  > 
  > inc 10
  > EOF
  op inc x =
  x + 1
  
  inc 10
  #= 11

Comments are preserved:

  $ run <<EOF
  > # this is a comment
  > 1 2 3 + 4 5 6
  > EOF
  # this is a comment
  1 2 3 + 4 5 6
  #= 5 7 9

Whitespace is preserved:

  $ run <<EOF
  > 1 2 3 + 4 5 6
  > 
  >     1 2 3
  > 
  > 
  > "hello"
  > EOF
  1 2 3 + 4 5 6
  #= 5 7 9
  
      1 2 3
  #= 1 2 3
  
  
  "hello"
  #= hello

Indentation is currently ignored in output:

  $ run <<EOF
  >     1 2 3
  > EOF
      1 2 3
  #= 1 2 3

Error lines are matched with the correct source line even
when the reported line differs from the original source.

  $ run <<EOF
  > 1
  > 2
  > x
  > 3
  > 4
  > EOF
  1
  #= 1
  2
  #= 2
  #! undefined variable "x"
  x
  #! unreachable
  3
  #! unreachable
  4
  #! unreachable

When given a positional argument, it writes a .out file.

  $ cat >example.ivy <<EOF
  > x = 1 2 3
  > y = 4 5 6
  > #=
  > x + y
  > EOF
  $ run example.ivy
  $ cat example.ivy.out
  x = 1 2 3
  y = 4 5 6
  #= 4 5 6
  x + y
  #= 5 7 9

--dump-intermediate prints the intermediate compilation result to stderr.

  $ run example.ivy --dump-intermediate
  _ = 0 rho 0
  x = 1 2 3
  _privy = _
  y = 4 5 6
  y
  "\x00"
  _ = _privy
  x + y
  _privy = _
  "\x00"
  _ = _privy
  
Example of --dump-intermediate from the readme:

  $ run --dump-intermediate >/dev/null <<EOF
  > input = 199 200 208 210 200 207 240 269 260 263
  > 
  > butlast = -1 drop input
  > #=
  > 
  > butfirst = 1 drop input
  > #=
  > 
  > +/ 1 == sgn butfirst - butlast
  > EOF
  _ = 0 rho 0
  input = 199 200 208 210 200 207 240 269 260 263
  
  _privy = _
  butlast = -1 drop input
  butlast
  "\x00"
  _ = _privy
  
  _privy = _
  butfirst = 1 drop input
  butfirst
  "\x00"
  _ = _privy
  
  +/ 1 == sgn butfirst - butlast
  _privy = _
  "\x00"
  _ = _privy
  
Special commands are passed through correctly:

  $ run <<EOF
  > )ibase 2
  > 101
  > EOF
  )ibase 2
  101
  #= 5
