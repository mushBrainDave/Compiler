The project is to explore the trusting trust problem by creating a simple compiler that injects "malicious" code. Said malicious code sends a ping to a server, nothing crazy. Uses Python style syntax.

TODO: The compiler detects if it's being used to compile a exe (injects ping) or compile a bootstrapped compiler (injects injection and ping).

Structure:  
main.asm - control flow, read source file (hardcoded location atm)  
parser.asm - tokenizes source file. Only handles comments, newlines, variables, formatted strings, function calls (kinda)  
lexer.asm - very basic syntax check. It's heavily assumed that the source file will be correct so it really only checks for two keywords 'print' and 'input'  
codegen.asm - creates the assembly file of the source file. Will handle code injection  
ping.asm - pings a server. Does pull in printf cause debugging with WriteConsoleA is tedious
