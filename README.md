# privy

`privy` is a preprocessor/postprocessor for the array language [ivy](https://github.com/robpike/ivy).

Given a source file, `privy` will produce a modified source file containing inline output from the expressions. For example, this input:

```ivy
input = 199 200 208 210 200 207 240 269 260 263

butlast = -1 drop input
#=

butfirst = 1 drop input
#=

+/ 1 == sgn butfirst - butlast
```

Becomes:

```ivy
input = 199 200 208 210 200 207 240 269 260 263

butfirst = 1 drop input
#= 200 208 210 200 207 240 269 260 263

butlast = -1 drop input
#= 199 200 208 210 200 207 240 269 260

+/ 1 == sgn butfirst - butlast
#= 7
```

Output lines start with `#=`. Error lines start with `#!`, and are reported inline with the errors:

```
input = 199 200 208 210 200 207 240 269 260 263

butfirst = 1 drop input
#= 200 208 210 200 207 240 269 260 263

butlast = -1 drop input
#= 199 200 208 210 200 207 240 269 260

#! undefined variable "buttfirst"
+/ 1 == sgn buttfirst - butlast
#! unreachable
#= 7
```

`privy` currently searches for `ivy` on your `PATH`, with no way to customize that.

At the moment all ivy programs are valid privy programs, and vice-versa. This may change in the future as I add the ability to easily import values and function definitions from other files.

# How does it work

`privy` "compiles" its input:

```ivy
input = 199 200 208 210 200 207 240 269 260 263

butlast = -1 drop input
#=

butfirst = 1 drop input
#=

+/ 1 == sgn butfirst - butlast
```

Into a corresponding ivy program:

```
input = 199 200 208 210 200 207 240 269 260 263

butlast = -1 drop input
butlast
"\x00"

butfirst = 1 drop input
butfirst
"\x00"

+/ 1 == sgn butfirst - butlast
"\x00"
```

Then it executes *that* program, splits the output on null bytes, and interleaves it with the original input.

You will notice the fragility: `privy` will fail to associate output to the correct input lines if your program outputs single null bytes like this. There is currently no way to choose a different output terminator.

# Tests

There are [cram tests](https://bitheap.org/cram/) that you can run or [peruse](test.t):

    $ cram test.t

Unfortunately trailing spaces are significant to cram, so be careful your editor doesn't trim them.

# Hacking

`privy` requires Janet 1.16.1, because this is the latest version of Janet packaged for Nix with a working `jpm`. You can enter a `nix-shell` with all of the correct dependencies by running:

```
nix-shell -I "nixpkgs=https://api.github.com/repos/NixOS/nixpkgs/tarball/$(cat shell.nix.lock)"
```
