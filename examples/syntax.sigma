extern print(int, string) -> none
extern strConcat(string, string) -> string
extern input() -> string
extern intFromStr(string) -> int

// Main function - entry point of the program
fn main() -> none
	var prompt: string = "Enter your input: ";  // Prompt message for user input
	print(#STRING, prompt);
	var in: string = input();                   // Get user input as string
	var in_int: int = intFromStr(in);           // Convert string to integer
	var res: int = factorial(in_int);           // Calculate factorial
	print(#INT, res)                            // Display the result

	return null;                                // End program execution
end

// Factorial function - calculates n! recursively
function factorial(num: int) -> int
	if (num == 0) then
		return 1;                               // Base case: 0! = 1
	else
		return num * factorial(num - 1);        // Recursive case: n! = n * (n-1)!
	end
end
