# Bytecode format

The bytecode requires constants to be defined:

```
global byte 0: Number of constants
```

Then for each constant:

```
byte 1: Constant type (enum as integer)
byte 2..x: Constant value (varies based on type)
```

The bytecode format is also organized into a list of Function objects. Each Function object contains the following fields:

* `return_type`: The return type of the function, represented as an integer.
* `param_types`: A list of parameter types, each represented as an integer.
* `instructions`: A list of Instruction objects, each representing a single operation in the function.


Each function is organized as so:

```
(Where byte 0 is the starting byte of the function definition)
byte 0: Return type
byte 1: Number of parameters
byte 2: Param type #1 
byte 3: Param type #2
...
(Assuming 3 parameters)
byte 5: Number of instructions
byte 6: Instruction #1
byte 7: Instruction #2
...
```

Then, since it's organized as a list, the bytecode defines with the number of functions


Overall, the bytecode format is structured as follows:

```
global byte 0: Number of constants
byte 1: Constant type (enum as integer)
byte 2..x: Constant value (varies based on type)
...
byte n: Number of functions
byte n+1..x: Function 1 definition
byte x+n..y: Function 2 definition
...
```
