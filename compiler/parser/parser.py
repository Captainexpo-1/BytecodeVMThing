from typing import List
from compiler.lexer.token import Token, TokenType, types
from compiler.parser.astnodes import (
    Expr, Stmt, Decl,
    Binary, Unary, Literal, Variable, Call, TypeLiteral,
    ExprStmt, VarDeclStmt, ReturnStmt, IfStmt,
    Param, FunctionDecl, Program,
    Type, WhileLoop, Assignment, TransPointer
)

class ParseError(Exception):
    def __init__(self, token: Token, message: str):
        self.token = token
        self.message = message
        super().__init__(f"Parse error at {token}: {message}")

class Parser:
    OPERATORS = {
        TokenType.ASSIGN:    (1, 'right'),
        TokenType.AS:        (1, 'left'),
        TokenType.EQ:        (1, 'left'),
        TokenType.NEQ:       (1, 'left'),
        TokenType.LT:        (2, 'left'),
        TokenType.GT:        (2, 'left'),
        TokenType.PLUS:      (3, 'left'),
        TokenType.MINUS:     (3, 'left'),
        TokenType.STAR:      (4, 'left'),
        TokenType.DIVIDE:    (4, 'left'),
    }
    UNARY_OPERATORS = {
        TokenType.MINUS,
        TokenType.BANG,
        TokenType.AMPERSAND,
        TokenType.STAR,
    }

    
    def __init__(self, tokens: List[Token]):
        self.tokens: List[Token] = tokens
        self.current: int = 0
        self.errors: List[ParseError] = []
    
    def parse(self) -> Program:
        """Parse the tokens into an AST."""
        declarations = []
        
        while not self.is_at_end():
            try:
                declarations.append(self.declaration())
            except ParseError as e:
                self.errors.append(e)
                self.synchronize()
        
        # Return the program with line/column from first token if present
        if len(self.tokens) > 0:
            token = self.tokens[0]
            return Program(line=token.line, column=token.column, declarations=declarations)
        return Program(line=0, column=0, declarations=declarations)

    # Parsing declarations
    
    def declaration(self) -> Decl:
        if self.match(TokenType.EXTERN):
            return self.extern_declaration()
        if self.match(TokenType.FN, TokenType.FUNCTION):
            return self.function_declaration()
        
        raise self.error(self.peek(), "Expected declaration")
    
    def extern_declaration(self) -> FunctionDecl:
        name = self.consume(TokenType.IDENTIFIER, "Expected function name after 'extern'")
        self.consume(TokenType.LPAREN, "Expected '(' after function name")
        is_variadic = False
        params = []
        if self.match(TokenType.DOTDOTDOT):
            # Handle variadic parameters
            is_variadic = True
        elif not self.check(TokenType.RPAREN):
            while True:
                
                type_token = self.consume_any(types, "Expected parameter type")
                if type_token.token_type not in [TokenType.INT, TokenType.STRING, TokenType.NONE]:
                    # To support more types like INT, STRING
                    self.consume([TokenType.INT, TokenType.STRING, TokenType.NONE], "Expected type")
                
                param_type = Type.from_token_value(type_token.value)
                params.append(Param(name="", type=param_type))
                
                if not self.match(TokenType.COMMA):
                    break
        
        self.consume(TokenType.RPAREN, "Expected ')' after parameters")
        self.consume(TokenType.ARROW, "Expected '->' after parameter list")
        
        
        return_type = self.parse_type()
        
        # Optional semicolon
        self.match(TokenType.SEMICOLON)
        
        return FunctionDecl(
            line=name.line,
            column=name.column,
            name=name.value,
            params=params,
            is_variadic=is_variadic,
            return_type=return_type,
            body=[],
            is_extern=True
        )
    
    def function_declaration(self) -> FunctionDecl:
        _token_type = self.previous().token_type
        name = self.consume(TokenType.IDENTIFIER, "Expected function name")
        self.consume(TokenType.LPAREN, "Expected '(' after function name")
        is_variadic = False
        params = []
        if self.match(TokenType.DOTDOTDOT):
            # Handle variadic parameters
            is_variadic = True
        elif not self.check(TokenType.RPAREN):
                
            while True:
                param_name = self.consume(TokenType.IDENTIFIER, "Expected parameter name").value
                self.consume(TokenType.COLON, "Expected ':' after parameter name")
                
                type_token = self.advance()
                if type_token.token_type not in [TokenType.INT, TokenType.STRING, TokenType.NONE]:
                    raise self.error(type_token, "Expected parameter type")
                
                param_type = Type.from_token_value(type_token.value)
                params.append(Param(name=param_name, type=param_type))
                
                if not self.match(TokenType.COMMA):
                    break
        
        self.consume(TokenType.RPAREN, "Expected ')' after parameters")
        self.consume(TokenType.ARROW, "Expected '->' after parameter list")
        
        return_type = self.parse_type()
        
        # Parse the function body statements
        body = []
        while not self.check(TokenType.END) and not self.is_at_end():
            body.append(self.statement())
        
        self.consume(TokenType.END, "Expected 'end' after function body")
        
        return FunctionDecl(
            line=name.line,
            column=name.column,
            name=name.value,
            params=params,
            return_type=return_type,
            body=body,
            is_extern=False,
            is_variadic=is_variadic
        )
    
    # Parsing statements
    
    def statement(self) -> Stmt:
        if self.match(TokenType.IF):
            return self.if_statement()
        if self.match(TokenType.RETURN):
            return self.return_statement()
        if self.match(TokenType.VAR):
            return self.var_declaration()
        if self.match(TokenType.WHILE):
            return self.while_statement()
        
        return self.expression_statement()
    
    def if_statement(self) -> IfStmt:
        token = self.previous()
        condition = self.expression()
        self.consume(TokenType.THEN, "Expected 'then' after condition")
        
        then_branch = []
        while not self.check(TokenType.ELSE) and not self.check(TokenType.END) and not self.is_at_end():
            then_branch.append(self.statement())
        
        else_branch = None
        if self.match(TokenType.ELSE):
            else_branch = []
            while not self.check(TokenType.END) and not self.is_at_end():
                else_branch.append(self.statement())
        
        self.consume(TokenType.END, "Expected 'end' after if body")
        
        return IfStmt(
            line=token.line,
            column=token.column,
            condition=condition,
            then_branch=then_branch,
            else_branch=else_branch
        )
    
    def return_statement(self) -> ReturnStmt:
        token = self.previous()
        
        value = None
        if not self.check(TokenType.SEMICOLON):
            value = self.expression()
        
        # Optional semicolon
        self.match(TokenType.SEMICOLON)
        
        return ReturnStmt(
            line=token.line,
            column=token.column,
            value=value
        )
    
    def while_statement(self) -> WhileLoop:
        condition = self.expression()
        self.consume(TokenType.THEN, "Expected 'then' after condition")
        
        body = []
        while not self.check(TokenType.END) and not self.is_at_end():
            body.append(self.statement())
        self.consume(TokenType.END, "Expected 'end' after while body")
        return WhileLoop(
            line=condition.line,
            column=condition.column,
            condition=condition,
            body=body
        )
    
    def var_declaration(self) -> VarDeclStmt:
        token = self.previous()
        name = self.consume(TokenType.IDENTIFIER, "Expected variable name").value
        
        self.consume(TokenType.COLON, "Expected ':' after variable name")
        
        
        
        var_type = self.parse_type()
        
        initializer = None
        if self.match(TokenType.ASSIGN):
            initializer = self.expression()
        
        # Optional semicolon
        self.match(TokenType.SEMICOLON)
        
        return VarDeclStmt(
            line=token.line,
            column=token.column,
            name=name,
            type=var_type,
            initializer=initializer
        )
    

    def expression_statement(self) -> ExprStmt:
        expr = self.expression()
        
        self.match(TokenType.SEMICOLON)
        
        return ExprStmt(
            line=expr.line,
            column=expr.column,
            expression=expr
        )
    
    def expression(self) -> Expr:
        return self.parse_precedence(0)

    def parse_precedence(self, min_prec: int) -> Expr:
        expr = self.parse_unary()

        while True:
            token = self.peek()
            op_info = self.OPERATORS.get(token.token_type)
            if not op_info:
                break
            prec, assoc = op_info
            if prec < min_prec:
                break

            self.advance()
            next_min_prec = prec + 1 if assoc == 'left' else prec
            right = self.parse_precedence(next_min_prec)
            
            # Handle assignment expressions
            if token.token_type == TokenType.ASSIGN:
                if not self._is_valid_assignment_target(expr):
                    raise self.error(token, "Invalid assignment target")
                expr = Assignment(
                    line=expr.line,
                    column=expr.column,
                    target=expr,
                    value=right
                )
            else:
                expr = Binary(
                    line=expr.line,
                    column=expr.column,
                    left=expr,
                    operator=token.value,
                    right=right
                )
        return expr
    
    def _is_valid_assignment_target(self, expr: Expr) -> bool:
        """Check if an expression is a valid assignment target."""
        return isinstance(expr, Variable) or (
            isinstance(expr, Unary) and expr.operator == "*"
        )

    def parse_unary(self) -> Expr:
        print("Parsing unary expression, current token:", self.peek())
        token = self.peek()
        if token.token_type in self.UNARY_OPERATORS:
            self.advance()
            right = self.parse_unary()
            return Unary(
                line=token.line,
                column=token.column,
                operator=token.value,
                right=right
            )
        return self.call()
    
    def call(self) -> Expr:
        expr = self.primary()
        
        if isinstance(expr, Variable) and self.match(TokenType.LPAREN):
            token = self.previous()
            arguments = []
            
            if not self.check(TokenType.RPAREN):
                while True:
                    arguments.append(self.expression())
                    if not self.match(TokenType.COMMA):
                        break
            
            self.consume(TokenType.RPAREN, "Expected ')' after arguments")
            
            return Call(
                line=token.line,
                column=token.column,
                callee=expr.name,
                arguments=arguments
            )
        
        return expr
    
    def primary(self) -> Expr:
        token = self.peek()
        
        if self.match(TokenType.INTEGER_LITERAL):
            return Literal(
                line=token.line,
                column=token.column,
                value=int(token.value)
            )
        
        if self.match(TokenType.STRING_LITERAL):
            # Remove quotes
            value = token.value
            if value.startswith('"') and value.endswith('"'):
                value = value[1:-1]
            return Literal(
                line=token.line,
                column=token.column,
                value=value
            )
        if self.match(TokenType.BOOL_LITERAL):
            return Literal(
                line=token.line,
                column=token.column,
                value=token.value.lower() == "true"
            )
        if self.match(TokenType.FLOAT_LITERAL):
            try:
                value = float(token.value)
            except ValueError:
                raise self.error(token, "Invalid float literal")
            return Literal(
                line=token.line,
                column=token.column,
                value=value
            )
        if self.match(TokenType.NULL):
            return Literal(
                line=token.line,
                column=token.column,
                value=None
            )
        
        if self.match(TokenType.HASH):
            # For #STRING, #INT type literals
            type_token = self.advance()
            return TypeLiteral(
                line=token.line,
                column=token.column,
                name=type_token.value
            )
        
        if self.match(TokenType.IDENTIFIER):
            return Variable(
                line=token.line,
                column=token.column,
                name=token.value
            )
        
        if self.match(TokenType.LPAREN):
            expr = self.expression()
            self.consume(TokenType.RPAREN, "Expected ')' after expression")
            return expr
        
        raise self.error(self.peek(), "Expected expression")
    
    
    def parse_type(self) -> Type:
        token = self.peek()
        
        if self.match(TokenType.INT):
            return Type.INT
        if self.match(TokenType.STRING):
            return Type.STRING
        if self.match(TokenType.NONE):
            return Type.NONE
        if self.match(TokenType.BOOL):
            return Type.BOOL
        if self.match(TokenType.FLOAT):
            return Type.FLOAT
        if self.match(TokenType.POINTER):
            self.consume(TokenType.LPAREN, "Expected '(' after 'pointer'")
            parsed = self.parse_type()
            self.consume(TokenType.RPAREN, "Expected ')' after pointer type")
            return TransPointer(parsed)
        
        raise self.error(token, "Expected type")
    
    # Helper methods
    
    def match(self, *types) -> bool:
        """Check if the current token matches any of the given types."""
        for type in types:
            if self.check(type):
                self.advance()
                return True
        return False
    
    def check(self, type) -> bool:
        """Check if the current token is of the given type."""
        if self.is_at_end():
            return False
        return self.peek().token_type == type
    
    def check_any(self, types: List[TokenType]) -> bool:
        """Check if the current token is of any of the given types."""
        if self.is_at_end():
            return False
        return self.peek().token_type in types
    
    def advance(self) -> Token:
        """Advance to the next token and return the previous one."""
        if not self.is_at_end():
            self.current += 1
        return self.previous()
    
    def is_at_end(self) -> bool:
        """Check if we've reached the end of input."""
        return self.peek().token_type == TokenType.EOF
    
    def peek(self) -> Token:
        """Return the current token without consuming it."""
        return self.tokens[self.current]
    
    def previous(self) -> Token:
        """Return the previous token."""
        return self.tokens[self.current - 1]
    
    def consume(self, type, message) -> Token:
        """Consume the current token if it matches the expected type."""
        if type is None or self.check(type):
            return self.advance()
        
        raise self.error(self.peek(), message)
    
    def consume_any(self, types: List[TokenType], message: str) -> Token:
        """Consume the current token if it matches any of the expected types."""
        if self.check_any(types):
            return self.advance()
        
        raise self.error(self.peek(), message)
    
    def error(self, token: Token, message: str) -> ParseError:
        """Create a parse error at the given token."""
        return ParseError(token, message)
    
    def synchronize(self):
        """Synchronize the parser after an error."""
        self.advance()
        
        while not self.is_at_end():
            # Synchronize at statement boundaries
            if self.previous().token_type == TokenType.SEMICOLON:
                return
            
            if self.peek().token_type in [
                TokenType.FN,
                TokenType.FUNCTION,
                TokenType.VAR,
                TokenType.IF,
                TokenType.RETURN,
                TokenType.EXTERN
            ]:
                return
            
            self.advance()