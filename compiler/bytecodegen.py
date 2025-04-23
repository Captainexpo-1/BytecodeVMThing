from typing import List, Any
from enum import Enum
import argparse
from dataclasses import dataclass


globalnum = 0


def _auto():
    global globalnum
    globalnum += 1
    return globalnum - 1

class OpCode(Enum):
    # No operation
    Nop = _auto()

    # Stack manipulation
    Dup = _auto()
    Swap = _auto()

    # Arithmetic (typed)
    AddI = _auto()
    AddF = _auto()
    SubI = _auto()
    SubF = _auto()
    MulI = _auto()
    MulF = _auto()
    DivI = _auto()
    DivF = _auto()
    ModI = _auto()

    # Logical (typed)
    AndB = _auto()  # Boolean AND
    OrB = _auto()
    NotB = _auto()
    XorB = _auto()

    # Bitwise (typed, usually int)
    ShlI = _auto()
    ShrI = _auto()
    BitAndI = _auto()
    BitOrI = _auto()
    BitXorI = _auto()

    # Comparison (typed)
    EqI = _auto()
    EqF = _auto()
    NeqI = _auto()
    NeqF = _auto()
    GtI = _auto()
    GtF = _auto()
    LtI = _auto()
    LtF = _auto()
    GeI = _auto()
    GeF = _auto()
    LeI = _auto()
    LeF = _auto()

    # Control flow
    Jmp = _auto()  # Unconditional jump
    Jz = _auto()  # Jump if zero (int or float == 0)
    Jnz = _auto()  # Jump if nonzero
    Jif = _auto()  # Jump if top of stack is true (bool)
    Call = _auto()  # Call function at address
    Ret = _auto()  # Return from function

    # Variable stack frame access
    LoadVar = _auto()
    StoreVar = _auto()

    # Pointer operations
    LoadAddr = _auto()  # Load address of variable
    Deref = _auto()  # Dereference pointer
    StoreDeref = _auto()  # Store value at pointer address

    # Heap (typed)
    AllocI = _auto()
    AllocF = _auto()
    FreeI = _auto()
    FreeF = _auto()

    # Casts (typed)
    CastIToF = _auto()
    CastFToI = _auto()

    # Constants
    LoadConst = _auto()

    # Halt VM
    Halt = _auto()

    # Foreign function interface
    CallFFI = _auto()

    # Advanced control flow
    TailCall = _auto()

globalnum = 0


class ValueType(Enum):
    INT = _auto()
    FLOAT = _auto()
    STRING = _auto()
    BOOL = _auto()
    NONE = _auto()
    LIST = _auto()
    STRUCT = _auto()
    POINTER = _auto()
    


@dataclass
class TransPointer:
    type: ValueType
    value: int = ValueType.POINTER.value

    def __str__(self):
        return f"ptrto {self.type}"


class Value:
    def __init__(self, value: Any, type: ValueType):
        self.value = value
        self.type = type

    def asBytes(self):
        if self.type == ValueType.FLOAT:
            import struct
            return struct.pack('<d', self.value)
        elif self.type == ValueType.STRING:
            encoded = self.value.encode('utf-8')
            encoded = len(encoded).to_bytes(4, byteorder='little') + encoded
            length = len(encoded)
            return length.to_bytes(4, byteorder='little') + encoded
        elif self.type == ValueType.BOOL:
            return bytes([1 if self.value else 0])
        elif self.type == ValueType.INT:
            return self.value.to_bytes(8, byteorder='little')
        return b''
    def __str__(self):
        return f"Value(value={self.value}, type={self.type})"
    def __repr__(self):
        return self.__str__()


class Instruction:
    def __init__(self, opcode: OpCode, arg: int = 0):
        self.opcode = opcode
        self.arg = arg

    def to_bytes(self):
        bytecode = self.opcode.value.to_bytes(1, byteorder='little')
        bytecode += self.arg.to_bytes(1, byteorder='little')
        return bytecode
    def __str__(self):
        return f"{self.opcode}({self.arg})"
    def __repr__(self):
        return self.__str__()


class Function:
    def __init__(self, arg_types: List[ValueType], return_type: ValueType, code: List[Instruction], is_variadic=False, name: str = "Unknown"):
        self.arg_types = arg_types
        self.return_type = return_type
        self.code = code
        self.is_variadic = is_variadic
        self.name = name

    def to_bytes(self):
        bytecode = self.return_type.value.to_bytes(1, byteorder='little')
        print("Return type:", self.return_type.value)
        print("Function arg types:", [arg_type.value for arg_type in self.arg_types])
        bytecode += len(self.arg_types).to_bytes(1, byteorder='little')
        for arg_type in self.arg_types:
            bytecode += bytes([arg_type.value])
        a = len(self.code).to_bytes(2, byteorder='little')
        bytecode += a
        print("Function code length:", len(self.code))
        for instr in self.code:
            print(f"Instruction: ({instr.opcode.value}){instr.opcode}", "Arg:", instr.arg)
            bytecode += instr.to_bytes()
        return bytecode
    
    def __str__(self):
        return f"\nFunction_{self.name}({("arg_types=" + str(self.arg_types)) if not self.is_variadic else "variadic"}, return_type={self.return_type}, code={"\n  "+'\n  '.join([str(i)for i in self.code])})"
    def __repr__(self):
        return self.__str__()



def genByteCode(constants: List[Value], functions: List[Function], output_file='bytecode.bin') -> None:
    with open(output_file, 'wb') as f:
        f.write(len(constants).to_bytes(1, byteorder='little'))
        for const in constants:
            f.write(bytes([const.type.value]))
            f.write(const.asBytes())
        print("Constants:", len(constants), "Functions:", len(functions))
        f.write(len(functions).to_bytes(1, byteorder='little'))
        for func in functions:
            f.write(func.to_bytes())

def readByteCode(input_file='bytecode.bin'):
    with open(input_file, 'rb') as f:
        num_constants = int.from_bytes(f.read(1), byteorder='little')
        constants = []
        for _ in range(num_constants):
            type_value = int.from_bytes(f.read(1), byteorder='little')
            type = ValueType(type_value)
            if type == ValueType.INT:
                value = int.from_bytes(f.read(8), byteorder='little')
            elif type == ValueType.FLOAT:
                import struct
                value = struct.unpack('<d', f.read(8))[0]
            elif type == ValueType.STRING:
                length = int.from_bytes(f.read(4), byteorder='little')
                value = f.read(length).decode('utf-8')
            elif type == ValueType.BOOL:
                value = bool(int.from_bytes(f.read(1), byteorder='little'))
            else:
                raise ValueError("Unsupported constant type")
            constants.append(Value(value, type))
        num_functions = int.from_bytes(f.read(1), byteorder='little')
        functions = []
        for _ in range(num_functions):
            return_type_value = int.from_bytes(f.read(1), byteorder='little')
            return_type = ValueType(return_type_value)
            num_args = int.from_bytes(f.read(1), byteorder='little')
            arg_types = [ValueType(int.from_bytes(f.read(1), byteorder='little')) for _ in range(num_args)]
            code_length = int.from_bytes(f.read(2), byteorder='little')
            code = [Instruction(OpCode(int.from_bytes(f.read(1), byteorder='little')), int.from_bytes(f.read(1), byteorder='little')) for _ in range(code_length)]
            functions.append(Function(arg_types, return_type, code))
    return constants, functions


def getData():
    constants = [
        Value(0, ValueType.INT), 
        Value(1, ValueType.INT),
        Value(10, ValueType.INT),
        Value(6, ValueType.INT),
        Value(ValueType.INT.value, ValueType.INT), 
        Value("Enter your input: ", ValueType.STRING),
        Value(ValueType.STRING.value, ValueType.INT),
    ]
    
    functions = [
        Function(
            arg_types=[],  # No arguments
            return_type=ValueType.NONE,  # Returns a float
            code = [
                Instruction(OpCode.LoadConst, 5),  # Load constant 5
                Instruction(OpCode.LoadConst, 6),  # Load constant 6
                Instruction(OpCode.CallFFI, 0),  # Load constant 7
                Instruction(OpCode.CallFFI, 2),
                Instruction(OpCode.CallFFI, 3),  # Convert 5.0 to int
                Instruction(OpCode.Call, 1),  # Call factorial
                Instruction(OpCode.LoadConst, 4), 
                Instruction(OpCode.CallFFI, 0),
                Instruction(OpCode.Halt)  # Halt the program
            ]
        ),
        # Factorial function
        Function(
            arg_types=[ValueType.INT],  # Takes one argument (n)
            return_type=ValueType.INT,  # Returns a float
            code=[
                Instruction(OpCode.LoadVarI, 0),  # Load n
                Instruction(OpCode.LoadConst, 0),  # Load constant 0
                Instruction(OpCode.EqI),  # If n == 0, jump to recursion
                Instruction(OpCode.Jif, 11),  # If n == 0, jump to recursion

                Instruction(OpCode.LoadVarI, 0),  # Load n
                Instruction(OpCode.LoadConst, 1),  # Load constant 1
                Instruction(OpCode.SubI),  # n - 1
                Instruction(OpCode.Call, 1),  # Call factorial(n - 1)
                Instruction(OpCode.LoadVarI, 0),  # Load n
                Instruction(OpCode.MulI),  # n * factorial(n - 1)
                Instruction(OpCode.Ret),  # Return the result
                
                Instruction(OpCode.LoadConst, 1),  # Load constant 1
                Instruction(OpCode.Ret),  # Return 1
            ]
        )
    ]
    
    return constants, functions


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate bytecode for the virtual machine.")
    parser.add_argument(
        "-o", "--output",
        type=str,
        default="bytecode.bin",
        help="Output file name for the generated bytecode (default: bytecode.bin)"
    )
    parser.add_argument(
        "-i", "--input",
        type=str,
        default="bytecode.bin",
        help="Input file name for the generated bytecode (default: bytecode.bin)"
    )
    args = parser.parse_args()

    if args.input:
        constants, functions = readByteCode(args.input)
        print("Constants:", constants)
        print("Functions:", functions)
    elif args.output:
        constants, functions = getData()
        
        genByteCode(constants, functions, output_file=args.output)