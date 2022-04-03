# privy

`privy` is a preprocessor/postprocessor for the array language [ivy](https://github.com/robpike/ivy).

Given a source file, `privy` will produce a modified source file containing inline output from the expressions. For example, this input:

```ivy
1 2 3 + 4 5 6
```

Becomes:

```ivy
1 2 3 + 4 5 6
#= 5 7 9
```

Which is not a very interesting example.

Output lines are prefixed with `#=`. Error lines are prefixed with `#!`.

You can see the value of an assigned variable by adding `#=` after any assignment:

```ivy
x = 1 2 3
y = x + x
#=

x + y
```

Becomes:

```ivy
x = 1 2 3
y = x + x
#= 2 4 6

x + y
#= 3 6 9
```

`privy` currently searches for `ivy` on your `PATH`. There is no way to customize that.

At the moment all ivy programs are valid privy programs, and vice-versa. This may change in the future as I add the ability to easily import values and function definitions from other files.

# How does it work

`privy` compiles the input program into another program that contains `"\x00"` after every statement that will output something. So:

```ivy
2 * 1 2 3
3 * 1 2 3
```

Becomes:

```ivy
2 * 1 2 3
"\x00"
3 * 1 2 3
"\x00"
```

Then it executes *that* `ivy` program, splits the output on null bytes, and interleaves it with the original input.

`privy` will fail to associate output to the correct input lines if your program outputs single null bytes like this. There is currently no way to choose a different output terminator.

# Tests

There are [cram tests](https://bitheap.org/cram/) that you can run or [peruse](test.t):

    $ cram test.t

Unfortunately trailing spaces are significant to cram, so be careful your editor doesn't trim them.
