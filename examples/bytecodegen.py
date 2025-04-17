
from typing import List, Any

from enum import Enum
import argparse
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

    # Arithmetic operations
    Add = _auto()
    Sub = _auto()
    Mul = _auto()
    Div = _auto()
    Mod = _auto()

    # Logical operations
    And = _auto()
    Or = _auto()
    Not = _auto()
    Xor = _auto()

    # Bitwise operations
    Shl = _auto()
    Shr = _auto()
    BitAnd = _auto()
    BitOr = _auto()
    BitXor = _auto()

    # Comparison operations
    Eq = _auto()
    Neq = _auto()
    Gt = _auto()
    Lt = _auto()
    Ge = _auto()
    Le = _auto()

    # Control flow
    Jmp = _auto()
    Jz = _auto()
    Jnz = _auto()
    Jif = _auto()
    Call = _auto()
    Ret = _auto()

    # Variables
    LoadVar = _auto()
    StoreVar = _auto()

    # Pointer operations
    LoadAddress = _auto()  # Create a pointer to a variable
    Deref = _auto()        # Access the value a pointer points to
    StoreDeref = _auto()   # Update the value a pointer points to

    # Heap
    Alloc = _auto()
    Free = _auto()

    # Cast operations
    CastToInt = _auto()
    CastToFloat = _auto()

    # Load and halt
    LoadConst = _auto()
    Halt = _auto()

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

class Instruction:
    def __init__(self, opcode: OpCode, arg: int = 0):
        self.opcode = opcode
        self.arg = arg
    def to_bytes(self):
        bytecode = self.opcode.value.to_bytes(1, byteorder='little')
        bytecode += self.arg.to_bytes(1, byteorder='little')
        return bytecode

class Function:
    def __init__(self, arg_types: List[ValueType], return_type: ValueType, code: List[Instruction]):
        self.arg_types = arg_types
        self.return_type = return_type
        self.code = code
        
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

def genByteCode(constants: List[Value], functions: List[Function], output_file='bytecode.bin'):
    with open(output_file, 'wb') as f:
        f.write(len(constants).to_bytes(1, byteorder='little'))
        for const in constants:
            f.write(bytes([const.type.value]))
            f.write(const.asBytes())
        print("Constants:", len(constants), "Functions:", len(functions))
        f.write(len(functions).to_bytes(1, byteorder='little'))
        for func in functions:
            f.write(func.to_bytes())

def getData():
    constants = [
        Value(1, ValueType.INT),  # Constant 1 (1.0)
        Value(10, ValueType.INT),  # Constant 2 (the input)
    ]
    
    functions = [
        Function(
            arg_types=[],  # No arguments
            return_type=ValueType.NONE,  # Returns a float
            code = [
                Instruction(OpCode.LoadConst, 0), # Load constant 0 (1)
                Instruction(OpCode.StoreVar, 0),  # Store in variable 0
                Instruction(OpCode.LoadConst, 1), # Load constant 1 (10)
                Instruction(OpCode.LoadAddress, 0),  # Load get pointer to variable 0
                Instruction(OpCode.StoreDeref), # Store the value at the pointer
                Instruction(OpCode.Halt)  # Halt the program
            ]
        ),
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
    args = parser.parse_args()
    
    constants, functions = getData()
    genByteCode(constants, functions, output_file=args.output)
