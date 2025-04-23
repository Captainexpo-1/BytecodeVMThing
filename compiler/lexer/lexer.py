import re

from compiler.lexer.token import (
    Token,
    TokenType
)

class Lexer:
    def __init__(self, source_code):
        self.source_code = source_code
        self.tokens = []

        # Define token patterns
        self.token_specs = [
            ('COMMENT', r'//[^\n]*'),                          # Line comments
            ('EXTERN', r'extern\b'),                             # extern keyword
            ('FN', r'fn\b'),                                     # fn keyword
            ('FUNCTION', r'function\b'),                         # function keyword
            ('IF', r'if\b'),                                     # if keyword
            ('THEN', r'then\b'),                                 # then keyword
            ('ELSE', r'else\b'),                                 # else keyword
            ('END', r'end\b'),                                   # end keyword
            ('RETURN', r'return\b'),                             # return keyword
            ('VAR', r'var\b'),                                   # var keyword
            ('NULL', r'null\b'),                                 # null literal
            ('INT', r'int\b'),                                   # int type
            ('STRING', r'string\b'),                             # string type
            ('BOOL', r'bool\b'),                                 # bool type
            ('FLOAT', r'float\b'),                               # float type
            ('POINTER', r'pointer\b'),                           # pointer keyword
            ('NONE', r'none'),                                 # none keyword
            ('WHILE', r'while\b'),                               # while keyword
            ('AS', r'as\b'),                                   # as keyword
            ('ARROW', r'->'),                                  # Arrow
            ('FLOAT_LITERAL', r'\d+\.\d+'),                    # Float
            ('INTEGER_LITERAL', r'\d+'),                       # Integer
            ('STRING_LITERAL', r'"[^"]*"'),                    # String literal
            ('BOOL_LITERAL', r'true|false'),                   # Boolean literal
            ('AND', r'&&'),                                    # Logical AND
            ('OR', r'\|\|'),                                   # Logical OR
            ('BANG', r'!'),                                    # Logical NOT
            ('AMPERSAND', r'&'),                               # Bitwise AND
            ('PIPE', r'\|'),                                   # Bitwise OR
            ('EQ', r'=='),                                     # Equals
            ('NEQ', r'!='),                                    # Not equals
            ('LT', r'<'),                                      # Less than
            ('GT', r'>'),                                      # Greater than
            ('ASSIGN', r'='),                                  # Assign
            ('SEMICOLON', r';'),
            ('COMMA', r','),
            ('LPAREN', r'\('),
            ('RPAREN', r'\)'),
            ('LBRACE', r'\{'),
            ('RBRACE', r'\}'),
            ('COLON', r':'),
            ('HASH', r'#'),
            ('PLUS', r'\+'),
            ('MINUS', r'-'),
            ('STAR', r'\*'),
            ('DIVIDE', r'/'),
            ('NEWLINE', r'\n'),
            ('WHITESPACE', r'[ \t]+'),
            ('DOTDOTDOT', r'\.\.\.'),
            ('IDENTIFIER', r'[a-zA-Z_][a-zA-Z0-9_]*'),
        ]

        self.regex = '|'.join(f'(?P<{name}>{pattern})' for name, pattern in self.token_specs)
        self.pattern = re.compile(self.regex)

    def parse_string(self, string: str):
        # escape sequences
        string = string.replace('\\n', '\n')
        string = string.replace('\\t', '\t')
        string = string.replace('\\"', '"')
        string = string.replace("\\'", "'")
        string = string.replace('\\\\', '\\')
        return string

    def tokenize(self):
        pos = 0
        line = 1
        column = 1

        while pos < len(self.source_code):
            match = self.pattern.match(self.source_code, pos)
            if not match:
                print(f"Lexical error at line {line}, column {column}: Unexpected character '{self.source_code[pos]}'")
                pos += 1
                column += 1
                continue

            token_type = match.lastgroup
            token_value = match.group()
            start_column = column

            # Count newlines in matched token to update line/column accurately
            newline_count = token_value.count('\n')
            if newline_count > 0:
                line += newline_count
                column = len(token_value) - token_value.rfind('\n')
            else:
                column += len(token_value)

            pos = match.end()

            # Skip over whitespace and newlines entirely
            if token_type in ('WHITESPACE', 'NEWLINE'):
                continue

            # Skip comments
            if token_type == 'COMMENT':
                continue

            # Remove quotes from string literals
            if token_type == 'STRING_LITERAL':
                token_value = self.parse_string(token_value[1:-1])

            # Get enum type (fallback to UNKNOWN)
            try:
                enum_token_type = getattr(TokenType, token_type)
            except AttributeError:
                enum_token_type = TokenType.UNKNOWN

            # Create token
            token = Token(
                type=enum_token_type,
                value=token_value,
                line=line,
                column=start_column
            )
            self.tokens.append(token)

        # Add EOF token
        self.tokens.append(Token(
            type=TokenType.EOF,
            value='EOF',
            line=line,
            column=column
        ))

        return self.tokens


# Sample usage
if __name__ == "__main__":
    source_code = """extern print(int, string) -> none
// Main function
fn main() -> none
    var x: int = 5;
    return x;
end"""

    lexer = Lexer(source_code)
    tokens = lexer.tokenize()

    for token in tokens:
        print(token)
