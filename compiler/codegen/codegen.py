from typing import (
    List, 
    Dict,
    Any,
    Optional,
    Tuple
)
import compiler.parser.astnodes as ast
from compiler.lexer.token import (
    TokenType, 
    Token
)
from compiler.bytecodegen import (
    Function, 
    Instruction, 
    OpCode,
    ValueType,
    Value
)

class CodeGenerator:
    
    def __init__(self, ast):
        self.ast = ast
        self.functions: List[Function] = []
        self.current_function: Optional[Function] = None
        self.extern_functions: List[Function] = []
        self.locals: List[Tuple[str, ValueType]] = {}
        self.constants: List[Value] = []
        
    def add_instruction(self, opcode: OpCode, arg: int = 0):
        if self.current_function is None:
            raise Exception("No current function to add instruction to")
        i = Instruction(opcode, arg)
        self.current_function.code.append(i)
        return i
    
    def add_constant(self, value: Value):
        for i, const in enumerate(self.constants):
            if const.value == value.value and const.type == value.type:
                return i
        self.constants.append(value)
        return len(self.constants) - 1
    
    def generate_code(self):
        self.visit(self.ast)
        return self.functions, self.extern_functions

    def visit(self, node):
        method_name = f"visit_{node.__class__.__name__}"
        visitor = getattr(self, method_name, self.generic_visit)
        return visitor(node)

    def visit_Program(self, node: ast.Program):
        for stmt in node.declarations:
            self.visit(stmt)
        return self.functions, self.extern_functions

    def tokentype_to_value_type(self, token_type: TokenType) -> ValueType:
        assert isinstance(token_type, TokenType)
        m = {
            TokenType.INT: ValueType.INT,
            TokenType.FLOAT: ValueType.FLOAT,
            TokenType.STRING: ValueType.STRING,
            TokenType.BOOL: ValueType.BOOL,
            TokenType.POINTER: ValueType.POINTER,
            TokenType.NONE: ValueType.NONE
        }
        if token_type in m:
            return m[token_type]
        raise Exception(f"Unknown type: {token_type}")
    
    def ast_type_to_value_type(self, ast_type: ast.Type) -> ValueType:
        assert isinstance(ast_type, ast.Type)
        m = {
            ast.Type.INT: ValueType.INT,
            ast.Type.FLOAT: ValueType.FLOAT,
            ast.Type.STRING: ValueType.STRING,
            ast.Type.BOOL: ValueType.BOOL,
            ast.Type.POINTER: ValueType.POINTER,
            ast.Type.NONE: ValueType.NONE
        }
        if ast_type in m:
            return m[ast_type]
        raise Exception(f"Unknown type: {ast_type}")
    
    def get_instruction_type(self, instr_type: str, type: ValueType) -> OpCode:
        return {
            "storevar": {
                ValueType.INT: OpCode.StoreVarI,
                ValueType.FLOAT: OpCode.StoreVarF,
                ValueType.STRING: OpCode.StoreVarStr,
            },
            "loadvar": {
                ValueType.INT: OpCode.LoadVarI,
                ValueType.FLOAT: OpCode.LoadVarF,
                ValueType.STRING: OpCode.LoadVarStr,
            },
            "add": {
                ValueType.INT: OpCode.AddI,
                ValueType.FLOAT: OpCode.AddF,                
            },
            "sub": {
                ValueType.INT: OpCode.SubI,
                ValueType.FLOAT: OpCode.SubF,                
            },
            "mul": {
                ValueType.INT: OpCode.MulI,
                ValueType.FLOAT: OpCode.MulF,                
            },
            "div": {
                ValueType.INT: OpCode.DivI,
                ValueType.FLOAT: OpCode.DivF,                
            }
        }.get(instr_type, {}).get(type, OpCode.Nop)
        
    def visit_FunctionDecl(self, node: ast.FunctionDecl):
        return_type = node.return_type
        params = node.params
        body = node.body
        if node.is_extern:
            self.extern_functions.append(Function(
                arg_types=list(map(lambda param: self.ast_type_to_value_type(param.type), params)),
                return_type=self.ast_type_to_value_type(return_type),
                code=[]
            ))
            return
        self.current_function = Function(
            arg_types=list(map(lambda param: self.ast_type_to_value_type(param.type), params)),
            return_type=self.ast_type_to_value_type(return_type),
            code=[]
        )
        self.functions.append(self.current_function)
        self.locals = [(param.name, self.ast_type_to_value_type(param.type)) for param in params]
        for stmt in body:
            self.visit(stmt)
        self.current_function = None
        self.locals = []

    def find_local(self, name: str) -> int:
        for i, (local_name, _) in enumerate(self.locals):
            if local_name == name:
                return i
        return -1

    def visit_VarDeclStmt(self, node: ast.VarDeclStmt):
        if node.initializer:
            self.visit(node.initializer)
        if node.type is None:
            raise Exception("Variable type cannot be None")
        if self.find_local(node.name) != -1:
            raise Exception(f"Variable {node.name} already declared")
        
        self.locals.append((node.name, self.ast_type_to_value_type(node.type)))            
        return self.add_instruction(
            self.get_instruction_type("vardecl", self.ast_type_to_value_type(node.type)), 
        node.name)
    
    def get_type(self, instruction: Instruction) -> ValueType:
        if instruction.opcode in [OpCode.LoadVarI, OpCode.StoreVarI]:
            return ValueType.INT
        elif instruction.opcode in [OpCode.LoadVarF, OpCode.StoreVarF]:
            return ValueType.FLOAT
        elif instruction.opcode in [OpCode.LoadVarStr, OpCode.StoreVarStr]:
            return ValueType.STRING
        elif instruction.opcode == OpCode.LoadConst:
            return self.constants[instruction.arg].type
        raise Exception(f"Unknown instruction type: {instruction.opcode}")
    
    def visit_Binary(self, node: ast.Binary):
        left = self.visit(node.left)
        right = self.visit(node.right)
        l_type = self.get_type(left)
        r_type = self.get_type(right)
        if l_type != r_type:
            raise Exception(f"Type mismatch: {l_type} and {r_type}")
        if node.operator == "+":
            return self.add_instruction(self.get_instruction_type("add", l_type))
            
        raise Exception(f"Unknown binary operator: {node.op}")
    
    def visit_Literal(self, node: ast.Literal):
        const = None
        if isinstance(node.value, str):
            const = self.add_constant(Value(node.value, ValueType.STRING))
        elif isinstance(node.value, int):
            const = self.add_constant(Value(node.value, ValueType.INT))
        elif isinstance(node.value, float):
            const = self.add_constant(Value(node.value, ValueType.FLOAT))
        elif isinstance(node.value, bool):
            const = self.add_constant(Value(node.value, ValueType.BOOL))
        else:
            raise Exception(f"Unknown literal type: {type(node.value)}")
        return self.add_instruction(
            OpCode.LoadConst, const
        )
    def visit_ReturnStmt(self, node: ast.ReturnStmt):
        if node.value.value:
            self.visit(node.value)
        return self.add_instruction(OpCode.Ret)
    
    def generic_visit(self, node):
        raise Exception(f"No visit_{node.__class__.__name__} method")
