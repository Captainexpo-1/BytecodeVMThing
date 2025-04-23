from enum import Enum, auto

class TokenType(Enum):
    # Keywords
    FN = auto()           # fn
    FUNCTION = auto()     # function
    EXTERN = auto()       # extern
    VAR = auto()          # var
    IF = auto()           # if
    THEN = auto()         # then
    ELSE = auto()         # else
    END = auto()          # end
    RETURN = auto()       # return
    WHILE = auto()         # while
    AS = auto()           # as
    
    # Types
    INT = auto()          # int
    STRING = auto()       # string
    NONE = auto()         # none
    BOOL = auto()         # bool
    FLOAT = auto()        # float
    POINTER = auto()      # pointer
    
    # Literals
    INTEGER_LITERAL = auto()  # 123
    STRING_LITERAL = auto()   # "hello"
    BOOL_LITERAL = auto()     # true/false
    FLOAT_LITERAL = auto()    # 1.23
    NULL = auto()             # null
    
    # Operators
    PLUS = auto()         # +
    MINUS = auto()        # -
    STAR = auto()     # *
    DIVIDE = auto()       # /
    ASSIGN = auto()       # =
    EQ = auto()       # ==
    NEQ = auto()   # !=
    LT = auto()    # <
    GT = auto() # >
    BANG = auto()   # !
    AND = auto()   # &&
    OR = auto()    # ||
    AMPERSAND = auto()   # &
    PIPE = auto()   # |
    
    # Punctuation
    LPAREN = auto()   # (
    RPAREN = auto()  # )
    LBRACE = auto()   # {
    RBRACE = auto()  # }
    SEMICOLON = auto()    # ;
    COLON = auto()        # :
    COMMA = auto()        # ,
    ARROW = auto()        # ->
    HASH = auto()         # #
    DOTDOTDOT = auto()      # ...
    
    # Identifiers
    IDENTIFIER = auto()   # variable and function names
    
    # Special
    EOF = auto()          # End of file
    ERROR = auto()        # Lexical error
    UNKNOWN = auto()      # Unknown token


types: list[TokenType] = [
    TokenType.INT,
    TokenType.STRING,
    TokenType.NONE,
    TokenType.BOOL,
    TokenType.FLOAT,
    TokenType.POINTER
]
    
class Token:
    def __init__(self, type: TokenType, value: str = '', line: int = 0, column: int = 0):
        self.token_type = type
        self.value = value
        self.line = line
        self.column = column
    
    def __str__(self):
        return f"Token(type={self.token_type}, value='{self.value}', line {self.line} col {self.column})"
    
    def __repr__(self):
        return self.__str__()
    