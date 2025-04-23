#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv){
    char str[] = "Hello, World!";
    // element at index 3
    *(str + 3) = 'a';
    char elem3 = str[3];
    
    printf("%s\n", str);
}