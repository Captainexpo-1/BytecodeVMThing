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
    LoadVarI = _auto()
    LoadVarF = _auto()
    StoreVarI = _auto()
    StoreVarF = _auto()

    # Pointer operations (typed)
    LoadAddrI = _auto()
    DerefI = _auto()
    StoreDerefI = _auto()
    
    LoadAddrF = _auto()
    DerefF = _auto()
    StoreDerefF = _auto()

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

    def ffi(name: str) -> int:
        # name = name of the foreign function
        # returns the index of the foreign function
        
        for i, ffi_name in enumerate(FFI):
            if ffi_name == name:
                return i
        raise ValueError(f"Foreign function '{name}' not found")
    
    def const(name: str) -> int:
        # name = name of the constant
        # returns the index of the constant
        
        for i, (const_name, const_value) in enumerate(constants):
            if const_name == name:
                return i
        raise ValueError(f"Constant '{name}' not found")
    
    FFI = [
        "print",
        "str_concat",
        "input",
    ]
    
    constants = [
        ("prompt",Value("Hello! What is your name?\n", ValueType.STRING)),
        ("compliment",Value(" is a really good name!\n", ValueType.STRING)),
        ("str_type",Value(ValueType.STRING.value, ValueType.INT)), 
    ]
    

    functions = [
        Function(
            arg_types=[],  # No arguments
            return_type=ValueType.NONE,  # Returns a float
            code = [
                Instruction(OpCode.LoadConst, const("prompt")),  # Load constant 0 (5.0)
                Instruction(OpCode.LoadConst, const("str_type")),  # Load constant 1 (5.0)
                Instruction(OpCode.CallFFI, ffi("print")),  # Call foreign function
            
                Instruction(OpCode.CallFFI, ffi("input")),  # Call foreign function
                Instruction(OpCode.LoadConst, const("compliment")),  # Load constant 1 (5.0)
                Instruction(OpCode.CallFFI, ffi("str_concat")),  # Call foreign function
                Instruction(OpCode.LoadConst, const("str_type")),  # Load constant 1 (5.0)
                Instruction(OpCode.CallFFI, ffi("print")),  # Call foreign function
                Instruction(OpCode.Halt)  # Halt the program
            ]
        ),
    ]
    
    return [val for name, val in constants], functions


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