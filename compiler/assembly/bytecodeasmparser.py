import re
import argparse
from bytecodegen import OpCode, ValueType, Value, Instruction, Function, genByteCode

class ParseError(Exception):
    def __init__(self, line_number, message):
        self.line_number = line_number
        self.message = message
        super().__init__(f"Line {line_number}: {message}")

class BytecodeAsmParser:
    def __init__(self):
        self.constants = []
        self.functions = []
        self.labels = {}
        self.current_function = None
        self.current_function_idx = -1
        
        # Initialize maps for opcodes and value types
        self.opcode_map = {op.name.lower(): op for op in OpCode}
        self.type_map = {t.name.lower(): t for t in ValueType}
    
    def parse_file(self, filename):
        with open(filename, 'r') as f:
            lines = f.readlines()
        
        line_number = 0
        in_function = False
        function_code = []
        function_args = []
        function_return_type = None
        
        for line in lines:
            line_number += 1
            line = line.strip()
            line = re.sub(r'\s+', ' ', line)  # Normalize whitespace
            line = re.sub('#.+$', '', line)  # Remove comments
            print(line)
            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue
            
            try:
                # Function definition
                if match := re.match(r'function\s+(\w+)\s*\((.*?)\)\s*->\s*(\w+)', line):
                    if in_function:
                        raise ParseError(line_number, "Nested function definitions not allowed")
                    
                    in_function = True
                    _function_name = match.group(1)
                    args_str = match.group(2).strip()
                    return_type_str = match.group(3).strip()
                    
                    # Parse argument types
                    function_args = []
                    if args_str:
                        for arg in args_str.split(','):
                            arg = arg.strip().lower()
                            if arg not in self.type_map:
                                raise ParseError(line_number, f"Unknown type: {arg}")
                            function_args.append(self.type_map[arg])
                    
                    # Parse return type
                    if return_type_str.lower() not in self.type_map:
                        raise ParseError(line_number, f"Unknown return type: {return_type_str}")
                    function_return_type = self.type_map[return_type_str.lower()]
                    
                    function_code = []
                    self.current_function_idx = len(self.functions)
                    continue
                
                # End of function
                if line.lower() == 'end':
                    if not in_function:
                        raise ParseError(line_number, "Unexpected 'end' outside of function")
                    
                    # Replace label references with actual offsets
                    for i, instr in enumerate(function_code):
                        if isinstance(instr.arg, str) and instr.arg in self.labels:
                            function_code[i] = Instruction(instr.opcode, self.labels[instr.arg])
                    
                    self.functions.append(Function(function_args, function_return_type, function_code))
                    in_function = False
                    self.labels = {}  # Reset labels for next function
                    continue
                
                # Label definition
                if match := re.match(r'([a-zA-Z_]\w*):', line):
                    if not in_function:
                        raise ParseError(line_number, "Labels can only be defined inside functions")
                    
                    label_name = match.group(1)
                    self.labels[label_name] = len(function_code)
                    continue
                
                # Constant definition
                if match := re.match(r'const\s+(\w+)\s+(.*)', line):
                    type_str = match.group(1).lower()
                    value_str = match.group(2).strip()
                    
                    if type_str not in self.type_map:
                        if type_str == "type":
                            type_str = "int"
                            
                        else:
                            raise ParseError(line_number, f"Unknown type: {type_str}")
                    
                    val_type = self.type_map[type_str]
                    
                    # Parse the value based on type
                    if val_type == ValueType.INT:
                        print("Value:", value_str)
                        if value_str.lower() in self.type_map:
                            value_str = str(self.type_map[value_str.lower()].value)
                        elif not value_str.isdigit() and not (value_str.startswith('-') and value_str[1:].isdigit()):
                            raise ParseError(line_number, f"Invalid integer: {value_str}")
                        value = int(value_str)
                    elif val_type == ValueType.FLOAT:
                        try:
                            value = float(value_str)
                        except ValueError:
                            raise ParseError(line_number, f"Invalid float: {value_str}")
                    elif val_type == ValueType.STRING:
                        if not (value_str.startswith('"') and value_str.endswith('"')):
                            raise ParseError(line_number, f"String must be quoted: {value_str}")
                        value = value_str[1:-1]  # Remove quotes
                    elif val_type == ValueType.BOOL:
                        if value_str.lower() == 'true':
                            value = True
                        elif value_str.lower() == 'false':
                            value = False
                        else:
                            raise ParseError(line_number, f"Invalid boolean: {value_str}")
                    else:
                        raise ParseError(line_number, f"Unsupported constant type: {type_str}")
                    
                    self.constants.append(Value(value, val_type))
                    continue
                
                # Instruction
                if in_function:
                    parts = line.split(None, 1)
                    if not parts:
                        continue
                    
                    opcode_str = parts[0].lower()
                    
                    if opcode_str not in self.opcode_map:
                        raise ParseError(line_number, f"Unknown opcode: {opcode_str}")
                    
                    opcode = self.opcode_map[opcode_str]
                    arg = 0
                    
                    if len(parts) > 1:
                        arg_str = parts[1].strip()
                        
                        # Check if arg is a label reference
                        if opcode in [OpCode.Jmp, OpCode.Jz, OpCode.Jnz, OpCode.Jif]:
                            # For jump instructions, we'll resolve labels later
                            arg = arg_str
                        else:
                            try:
                                arg = int(arg_str)
                            except ValueError:
                                raise ParseError(line_number, f"Invalid argument: {arg_str}")
                    
                    function_code.append(Instruction(opcode, arg))
                    continue
                
                raise ParseError(line_number, f"Unexpected line: {line}")
                
            except ParseError as e:
                print(f"Error at line {line_number}: {e.message}")
                return None
        
        if in_function:
            print("Error: Function definition not closed at end of file")
            return None
            
        return self.constants, self.functions

def main():
    parser = argparse.ArgumentParser(description="Parse assembly code and generate bytecode")
    parser.add_argument("input_file", help="Assembly source file")
    parser.add_argument("-o", "--output", default="output.bin", help="Output bytecode file")
    args = parser.parse_args()
    
    asm_parser = BytecodeAsmParser()
    result = asm_parser.parse_file(args.input_file)
    
    if result:
        constants, functions = result
        genByteCode(constants, functions, args.output)
        print(f"Successfully compiled {args.input_file} to {args.output}")
        print(f"Generated {len(constants)} constants and {len(functions)} functions")

if __name__ == "__main__":
    main()