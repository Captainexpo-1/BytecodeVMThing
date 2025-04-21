from dataclasses import dataclass
from typing import List, Optional, Union, Any
from enum import Enum

class Type(Enum):
    INT = "int"
    STRING = "string"
    NONE = "none"
    BOOL = "bool"
    FLOAT = "float"
    POINTER = "pointer"
    
    
    @staticmethod
    def from_token_value(value):
        if value == "int":
            return Type.INT
        elif value == "string":
            return Type.STRING
        elif value == "none":
            return Type.NONE
        elif value == "bool":
            return Type.BOOL
        elif value == "float":
            return Type.FLOAT
        elif value == "pointer":
            return Type.POINTER
        raise ValueError(f"Unknown type: {value}")

# Base class for all AST nodes
@dataclass
class Node:
    line: int
    column: int

# Expressions
@dataclass
class Expr(Node):
    pass

@dataclass
class Binary(Expr):
    left: Expr
    operator: str
    right: Expr

@dataclass
class Unary(Expr):
    operator: str
    right: Expr

@dataclass
class Literal(Expr):
    value: Any
    
@dataclass
class Variable(Expr):
    name: str

@dataclass
class Call(Expr):
    callee: str
    arguments: List[Expr]
    
@dataclass
class TypeLiteral(Expr):
    name: str

# Statements
@dataclass
class Stmt(Node):
    pass

@dataclass
class ExprStmt(Stmt):
    expression: Expr

@dataclass
class VarDeclStmt(Stmt):
    name: str
    type: Type
    initializer: Optional[Expr]

@dataclass
class ReturnStmt(Stmt):
    value: Optional[Expr]

@dataclass
class IfStmt(Stmt):
    condition: Expr
    then_branch: List[Stmt]
    else_branch: Optional[List[Stmt]]

@dataclass
class BlockStmt(Stmt):
    statements: List[Stmt]

# Declarations
@dataclass
class Param:
    name: str
    type: Type
    
@dataclass
class Decl(Node):
    pass

@dataclass
class FunctionDecl(Decl):
    name: str
    params: List[Param]
    return_type: Type
    body: List[Stmt]
    is_extern: bool = False
    
@dataclass
class Program(Node):
    declarations: List[Decl]