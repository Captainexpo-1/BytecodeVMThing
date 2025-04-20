# Constants

# FFI functions:
# 0: print
# 1: strConcat
# 2: input
# 3: intFromStr

const int 0
const int 1
const int 2
const type INT
const string "Enter which Fibonacci number to calculate: "
const type STRING
const int 35

# Main function
function main() -> none
    # loadconst 4  # Load prompt string
    # loadconst 5  # Load STRING type
    # callffi 0    # Call print function
    # callffi 2    # Call input function
    # callffi 3    # Parse input to int
    loadconst 6
    call 1       # Call fibonacci with input
    loadconst 3  # Load INT type
    callffi 0    # Print result
    halt         # Stop execution
end

# Fibonacci function (recursive implementation)
function fibonacci(int) -> int
    loadvari 0   # Load argument n
    loadconst 0  # Load constant 0
    eqi          # Compare if n == 0
    jif case_zero  # Jump to case zero if n == 0
    
    loadvari 0   # Load n
    loadconst 1  # Load constant 1
    eqi          # Compare if n == 1
    jif case_one   # Jump to case one if n == 1
    
    # Calculate fib(n-1)
    loadvari 0   # Load n
    loadconst 1  # Load constant 1
    subi         # Calculate n-1
    call 1       # Call fibonacci(n-1)
    
    # Calculate fib(n-2)
    loadvari 0   # Load n again
    loadconst 2  # Load constant 2
    subi         # Calculate n-2
    call 1       # Call fibonacci(n-2)
    
    addi         # Add fibonacci(n-1) + fibonacci(n-2)
    ret          # Return result
    
case_zero:
    loadconst 0  # Load constant 0
    ret          # Return 0 for fibonacci(0)
    
case_one:
    loadconst 1  # Load constant 1
    ret          # Return 1 for fibonacci(1)
end