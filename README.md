

Implementations for Cornell's [CS 6120: Advanced Compilers self-guided course](https://www.cs.cornell.edu/courses/cs6120/2020fa/self-guided/)
, in Swift.


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

To run them:
```
swift test
```


## Examples

### Generate the CFG with GraphViz 

Given this bril file named `diamond.bril` :
```
@main {
  a: int = const 47;
  cond: bool = const true;
  br cond .left .right;
.left:
  a: int = const 1;
  jmp .end;
.right:
  a: int = const 2;
  jmp .end;
.end:
  print a;
}
```

First we convert it to json format by using the utility `bril2json` from the [original bril repo](https://github.com/sampsyo/bril) 

```
bril2json < diamond.bril > diamond.json 
```

This is necessary because SwiftyBril expects json files as input.

TODO: Accept both json or bril files as input.

Then, we can generate a pdf file showing the CFG with:

```
swift run SwiftyBril --graph /Path/To/diamond.json | dot -Tpdf -o cfgDiamond.pdf 
```

![alt text](https://github.com/doste/SwiftyBril/blob/main/Images/DiamondCFG.jpeg "Diamond CFG")

### Optimizations

Given this bril file named `rename-fold.bril` :
```
@main {
  v1: int = const 4;
  v2: int = const 0;
  mul1: int = mul v1 v2;
  add1: int = add v1 v2;
  v2: int = const 3;
  print mul1;
  print add1;
}
```

Again, first we convert it to json format:

```
bril2json < rename-fold.bril > rename-fold.json 
```

Then, if we run:

```
swift run SwiftyBril --graph /Path/To/rename-fold.json | dot -Tpdf -o cfgNoOpt.pdf 
```

It would show the unoptimized CFG:

![alt text](https://github.com/doste/SwiftyBril/blob/main/Images/RenameFoldUnoptCFG.jpeg "Rename Fold Unoptimized CFG")

But by applying the optimizations:

```
swift run SwiftyBril --dce --lvn --graph /Path/To/rename-fold.json | dot -Tpdf -o cfgOpt.pdf 
```

The resulting CFG would look like this:

![alt text](https://github.com/doste/SwiftyBril/blob/main/Images/RenameFoldOptCFG.jpeg "Rename Fold Optimized CFG")

Another way to look at the generated bril program would be by running:

```
swift run SwiftyBril --dce --lvn --print /Path/To/rename-fold.json
```

The standard output would show:

```
@main {
    mul1: int = const 0;
    add1: int = const 4;
    print mul1;
    print add1;
}
```
