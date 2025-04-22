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
from collections import OrderedDict

class CodeGenerator:
    
    def __init__(self, ast):
        self.ast = ast
        self.current_function: Optional[Function] = None
        self.locals: List[Tuple[str, ValueType]] = {}
        self.constants: List[Value] = []
        self.functions: OrderedDict[str, Function] = OrderedDict()
        self.extern_functions: OrderedDict[str, Function] = OrderedDict()
        self.cur_pos = lambda: len(self.current_function.code) if self.current_function else 0
    
    def get_extern_function(self, name: str) -> Tuple[Function, int]:
        # returns the extern function and its index
        if name not in self.extern_functions:
            raise Exception(f"Extern function {name} not found")
        function = self.extern_functions[name]
        index = list(self.extern_functions.keys()).index(name)
        return function, index
    
    def get_function(self, name: str) -> Tuple[Function, int]:
        # returns the function and its index
        if name not in self.functions:
            raise Exception(f"Function {name} not found")
        function = self.functions[name]
        index = list(self.functions.keys()).index(name)
        return function, index
        
    
    def add_function(self, name: str, function: Function):
        if name in self.functions:
            raise Exception(f"Function {name} already declared")
        self.functions[name] = function
        return len(self.functions) - 1
    
    def add_extern_function(self, name: str, function: Function):
        if name in self.extern_functions:
            raise Exception(f"Extern function {name} already declared")
        self.extern_functions[name] = function
        return len(self.extern_functions) - 1
    
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
        return self.visit_Program(self.ast)


    def visit(self, node):
        print("Visiting node:", node)
        method_name = f"visit_{node.__class__.__name__.lower()}"
        visitor = getattr(self, method_name, self.generic_visit)
        return visitor(node)

    def visit_Program(self, node: ast.Program):
        # First pass: register all functions
        for stmt in node.declarations:
            if isinstance(stmt, ast.FunctionDecl):
                self.register_function(stmt)
        
        # Second pass: generate code for function bodies
        for stmt in node.declarations:
            if isinstance(stmt, ast.FunctionDecl) and not stmt.is_extern:
                self.generate_function_body(stmt)
        
        return list(self.functions.values()), self.constants 

    def register_function(self, node: ast.FunctionDecl):
        return_type = self.ast_type_to_value_type(node.return_type)
        arg_types = list(map(lambda param: self.ast_type_to_value_type(param.type), node.params))
        
        if node.is_extern:
            self.add_extern_function(node.name, Function(
                arg_types=arg_types,
                return_type=return_type,
                code=[],
                is_variadic=node.is_variadic,
                name=node.name
            ))
        else:
            function = Function(
                arg_types=arg_types,
                return_type=return_type,
                code=[],
                is_variadic=node.is_variadic,
                name=node.name
            )
            self.add_function(node.name, function)

    def generate_function_body(self, node: ast.FunctionDecl):
        self.current_function, _ = self.get_function(node.name)
        self.locals = [(param.name, self.ast_type_to_value_type(param.type)) for param in node.params]
        
        for stmt in node.body:
            self.visit(stmt)
        
        self.current_function = None
        self.locals = []

    def visit_functiondecl(self, node: ast.FunctionDecl):
        # Functions are now registered in the first pass
        # Bodies are generated in the second pass
        pass
    
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
        m = {
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
            },
            "eq": {
                ValueType.INT: OpCode.EqI,
                ValueType.FLOAT: OpCode.EqF,
            },
            "neq": {
                ValueType.INT: OpCode.NeqI,
                ValueType.FLOAT: OpCode.NeqF,
            },
            "lt": {
                ValueType.INT: OpCode.LtI,
                ValueType.FLOAT: OpCode.LtF,
            },
            "gt": {
                ValueType.INT: OpCode.GtI,
                ValueType.FLOAT: OpCode.GtF,
            }
        }
        if instr_type in m:
            if type in m[instr_type]:
                return m[instr_type][type]
        raise Exception(f"Unknown instruction type: {instr_type} for type: {type}")
        
    """def visit_functiondecl(self, node: ast.FunctionDecl):
        return_type = node.return_type
        params = node.params
        body = node.body
                        
        if node.is_extern:
            self.add_extern_function(node.name, Function(
                arg_types=list(map(lambda param: self.ast_type_to_value_type(param.type), params)),
                return_type=self.ast_type_to_value_type(return_type),
                code=[],
                is_variadic=node.is_variadic,
                name=node.name
            ))
            return
        self.current_function = Function(
            arg_types=list(map(lambda param: self.ast_type_to_value_type(param.type), params)),
            return_type=self.ast_type_to_value_type(return_type),
            code=[],
            is_variadic=node.is_variadic,
            name=node.name
        )
        self.add_function(node.name, self.current_function)
        self.locals = [(param.name, self.ast_type_to_value_type(param.type)) for param in params]
        for stmt in body:
            self.visit(stmt)
        self.current_function = None
        self.locals = []"""

    def find_local(self, name: str) -> int:
        for i, (local_name, _) in enumerate(self.locals):
            if local_name == name:
                return i
        return -1
    
    def add_local(self, name: str, type: ValueType):
        if self.find_local(name) != -1:
            raise Exception(f"Variable {name} already declared")
        self.locals.append((name, type))
        return len(self.locals) - 1

    def visit_vardeclstmt(self, node: ast.VarDeclStmt):
        if node.initializer:
            self.visit(node.initializer)
        if node.type is None:
            raise Exception("Variable type cannot be None")
        if self.find_local(node.name) != -1:
            raise Exception(f"Variable {node.name} already declared")   
        t = self.ast_type_to_value_type(node.type)    
        self.add_instruction(self.get_instruction_type("storevar", t), self.add_local(node.name, t))
        return t
    
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
    
    
    def visit_binary(self, node: ast.Binary):
        l_type: ValueType = self.visit(node.left)
        r_type: ValueType = self.visit(node.right)
        if l_type != r_type:
            raise Exception(f"Type mismatch: {l_type} and {r_type}")
        if node.operator == "+":
            self.add_instruction(self.get_instruction_type("add", l_type))
            return l_type
        elif node.operator == "-":
            self.add_instruction(self.get_instruction_type("sub", l_type))
            return l_type
        elif node.operator == "*":
            self.add_instruction(self.get_instruction_type("mul", l_type))
            return l_type
        elif node.operator == "/":
            self.add_instruction(self.get_instruction_type("div", l_type))
            return l_type
        elif node.operator == "==":
            self.add_instruction(self.get_instruction_type("eq", l_type))
            return ValueType.BOOL
        # TODO: Add support for other binary operators
            
        raise Exception(f"Unknown binary operator: {node.operator}")
    
    def visit_literal(self, node: ast.Literal):
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
        self.add_instruction(
            OpCode.LoadConst, const
        )
        return self.constants[const].type
    def visit_returnstmt(self, node: ast.ReturnStmt) -> ValueType:
        if node.value:
            self.visit(node.value)
        self.add_instruction(OpCode.Ret)
        return ValueType.NONE
    
    def visit_exprstmt(self, node: ast.ExprStmt):
        return self.visit(node.expression)
    
    def visit_call(self, node: ast.Call):
        is_extern = False
        func: Optional[Function] = None
        index: Optional[int] = None
        
        
        if node.callee in self.extern_functions:
            func, index = self.get_extern_function(node.callee)
            is_extern = True
        elif node.callee in self.functions:
            func, index = self.get_function(node.callee)
        else:
            raise Exception(f"Function {node.callee} not found")
        
        args: List[ValueType] = []
        expected_arg_types = list(reversed(func.arg_types))
        
        print(args, func)

        
        print(func.is_variadic)
        
        if not func.is_variadic and len(node.arguments) > len(expected_arg_types):
            if not func.is_variadic:
                raise Exception(f"Function {node.callee} takes {len(expected_arg_types)} arguments, but {len(node.arguments)} were given")
        
        for idx, arg in enumerate(reversed(node.arguments)):
            a = self.visit(arg)
            assert isinstance(a, ValueType)
            args.append(a)
            if not func.is_variadic:
                if a != expected_arg_types[idx]:
                    raise Exception(f"Argument type mismatch: {a} and {func.arg_types[idx]}")
            
        self.add_instruction(
            OpCode.Call if not is_extern else OpCode.CallFFI, index
        )
            
        return func.return_type
    
    def visit_typeliteral(self, node: ast.TypeLiteral):
        c = -1
        match(node.name.lower()):
            case "int":
                c=self.add_constant(Value(ValueType.INT.value, ValueType.INT))
            case "float":
                c=self.add_constant(Value(ValueType.FLOAT.value, ValueType.INT))
            case "string":
                c=self.add_constant(Value(ValueType.STRING.value, ValueType.INT))
            case "bool":
                c=self.add_constant(Value(ValueType.BOOL.value, ValueType.INT))
            case "pointer":
                c=self.add_constant(Value(ValueType.POINTER.value, ValueType.INT))
            case "none":
                c=self.add_constant(Value(ValueType.NONE.value, ValueType.INT))
        self.add_instruction(
            OpCode.LoadConst, c
        )
        return ValueType.INT
    
    def visit_variable(self, node: ast.Variable) -> ValueType:
        local_index = self.find_local(node.name)
        if local_index == -1:
            raise Exception(f"Variable {node.name} not found")
        self.add_instruction(
            self.get_instruction_type("loadvar", self.locals[local_index][1]), local_index
        )
        return self.locals[local_index][1]
    
    def visit_ifstmt(self, node: ast.IfStmt):
        condition_type = self.visit(node.condition)
        if condition_type != ValueType.BOOL:
            raise Exception(f"Condition type must be bool, but got {condition_type}")
        
        jump = self.add_instruction(OpCode.Jz, 0)
        
        for stmt in node.then_branch:
            self.visit(stmt)
            
        jump_end = self.add_instruction(OpCode.Jmp, 0)
        jump.arg = self.cur_pos()
        
        if node.else_branch:
            for stmt in node.else_branch:
                self.visit(stmt)
        
        jump_end.arg = self.cur_pos()
        
        return ValueType.NONE
    
    def generic_visit(self, node):
        raise Exception(f"No visit_{node.__class__.__name__.lower()} method")
