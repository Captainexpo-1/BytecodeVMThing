fn main(): Int {
    var int x = 5;
    var int y = 10;

    var int z = x + y;

    var int ptr = &z;


    extern print(extern intToString(z));

    return 0;
}

fn add