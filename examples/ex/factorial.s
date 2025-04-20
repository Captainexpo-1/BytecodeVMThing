# Constants

# FFI functions:
# 0: print
# 1: strConcat
# 2: input
# 3: intFromStr

const int 0
const int 1 
const int 10
const int 6
const type INT  # ValueType.INT.value
const string "Enter your input: "
const type STRING  # ValueType.STRING.value

# Main function
function main() -> none
    loadconst 5  # Load "Enter your input: "
    loadconst 6  # Load ValueType.STRING.value
    callffi 0    # Call print function
    callffi 2    # Call input function
    callffi 3    # Parse input to int
    call 1       # Call factorial with input
    loadconst 4  # Load ValueType.INT
    callffi 0    # Print result
    halt         # Stop execution
end

# Factorial function
function factorial(int) -> int
    loadvari 0  # Load argument n
    loadconst 0  # Load constant 0
    eqi         # Compare if n == 0
    jif base_case # Jump to base case if n == 0
    
    loadvari 0  # Load n
    loadconst 1  # Load constant 1
    subi        # Calculate n-1
    call 1       # Recursive call factorial(n-1)
    loadvari 0  # Load n again
    muli        # Calculate n * factorial(n-1)
    ret          # Return result
    
base_case:
    loadconst 1  # Load constant 1
    ret          # Return 1 for factorial(0)
end