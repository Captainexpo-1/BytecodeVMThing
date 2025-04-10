
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
        Value(0.0, ValueType.FLOAT),  # Constant 0 (0.0)
        Value(1.0, ValueType.FLOAT),  # Constant 1 (1.0)
        Value(52.0, ValueType.FLOAT),  # Constant 2 (the input)
        Value(6.0, ValueType.FLOAT),  # Constant 3 (6.0)
    ]
    
    functions = [
        Function(
            arg_types=[],  # No arguments
            return_type=ValueType.NONE,  # Returns a float
            code = [
                Instruction(OpCode.LoadConst, 2),  # Load constant 0 (5.0)
                Instruction(OpCode.Call, 1),  # Call factorial(5.0)
                Instruction(OpCode.Halt)  # Halt the program
            ]
        ),
        # Factorial function
        Function(
            arg_types=[ValueType.FLOAT],  # Takes one argument (n)
            return_type=ValueType.FLOAT,  # Returns a float
            code=[
                Instruction(OpCode.LoadVar, 0),  # Load n
                Instruction(OpCode.Jz, 9),  # If n == 0, jump to recursion

                Instruction(OpCode.LoadVar, 0),  # Load n
                Instruction(OpCode.LoadConst, 1),  # Load constant 1
                Instruction(OpCode.Sub, 0),  # n - 1
                Instruction(OpCode.Call, 1),  # Call factorial(n - 1)
                Instruction(OpCode.LoadVar, 0),  # Load n
                Instruction(OpCode.Mul, 0),  # n * factorial(n - 1)
                Instruction(OpCode.Ret, 0),  # Return the result
                
                Instruction(OpCode.LoadConst, 1),  # Load constant 1
                Instruction(OpCode.Ret, 0),  # Return 1
            ]
        )
    ]
    genByteCode(constants, functions)

def factorial(n):
    if n == 0:
        return 1
    return n * factorial(n - 1)

def factorial(n):
    tmp = 0
    if n == 0: return 1
    tmp = n
    n = n - 1
    tmp = tmp * factorial(n)
    return tmp
