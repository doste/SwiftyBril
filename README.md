

Implementations for Cornell's [CS 6120: Advanced Compilers self-guided course](https://www.cs.cornell.edu/courses/cs6120/2020fa/self-guided/)
), in Swift.


## Usage

Build the program using:
```

swift run SwiftyBril <bril_program_json>

```
                        
There are a couple of command line options to pass:
```

swift run SwiftyBril [--dce] [--lvn] [--graph] [--debug] [--print] <bril_program_json>
                        
```

The command line options `--dce` and `--lvn` are to apply optimizations that remove dead code and perform local value numbering, respectively.
The `--graph` option prints the control flow graph of the program in dot format, which can be used to visualize it using tools like `dot`. For example, you can pipe the output to ` | dot -Tpdf -o cfg.pdf`.

The `--debug` option is to show debug information.
Finally, with `--print` we print to standard output the bril program (transformed if optimizations were applied).


Also, there are a couple of tests to run. They are loosely based on the ["official" tests]( https://github.com/sampsyo/bril/tree/main/examples/test).
To run them, just type:
```
swift test

```
