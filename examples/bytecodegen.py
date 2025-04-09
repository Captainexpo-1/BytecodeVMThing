
from typing import List, Any

from enum import Enum

class OpCode(Enum):
    # No operation
    Nop = 0

    # Stack manipulation
    Dup = 1
    Swap = 2

    # Arithmetic operations
    Add = 3
    Sub = 4
    Mul = 5
    Div = 6
    Mod = 7

    # Logical operations
    And = 8
    Or = 9
    Not = 10
    Xor = 11

    # Bitwise operations
    Shl = 12
    Shr = 13

    # Comparison operations
    Eq = 14
    Neq = 15
    Gt = 16
    Lt = 17
    Ge = 18
    Le = 19

    # Control flow
    Jmp = 20
    Jz = 21
    Jnz = 22
    Call = 23
    Ret = 24

    # Variables
    LoadVar = 25
    StoreVar = 26

    # Load and halt
    LoadConst = 27
    Halt = 28

class ValueType(Enum):
    FLOAT = 0
    STRING = 1
    BOOL = 2
    NONE = 3

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
        print(int.from_bytes(a, byteorder='little'))
        print("Function code length:", len(self.code))
        for instr in self.code:
            print("Instruction:", instr.opcode.value, "Arg:", instr.arg)
            bytecode += instr.to_bytes()
        return bytecode

def genByteCode(constants: List[Value], functions: List[Function]):
    with open('bytecode.bin', 'wb') as f:
        f.write(len(constants).to_bytes(1, byteorder='little'))
        for const in constants:
            f.write(bytes([const.type.value]))
            f.write(const.asBytes())
        print("Constants:", len(constants), "Functions:", len(functions))
        f.write(len(functions).to_bytes(1, byteorder='little'))
        for func in functions:
            f.write(func.to_bytes())
            
if __name__ == "__main__":
    constants = [
        Value(42.0, ValueType.FLOAT),  # Constant 0
        Value(3.14, ValueType.FLOAT),  # Constant 3
    ]
    
    functions = [
        Function(
            arg_types=[],
            return_type=ValueType.NONE,
            code=[
                Instruction(OpCode.LoadConst, 0),  # Load constant 0 (42.0)
                Instruction(OpCode.LoadConst, 1),  # Load constant 3 (3.14)
                Instruction(OpCode.Call, 1),          # Multiply
                Instruction(OpCode.Ret)           # Return result
            ]
        ),
        Function(
            arg_types=[ValueType.FLOAT, ValueType.FLOAT],
            return_type=ValueType.FLOAT,
            code=[
                Instruction(OpCode.LoadVar, 0),  # Load variable 0
                Instruction(OpCode.LoadVar, 1),  # Load variable 1
                Instruction(OpCode.Add),          # Add the two variables
                Instruction(OpCode.Ret, 125)           # Return result
            ]
        )
            
            
    ]
    genByteCode(constants, functions)
            