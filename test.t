  $ PATH=$HOME/go/bin:$PATH
  $ run() { 
  >   janet "$TESTDIR/main.janet" 
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
