# Desciption:
Collects register definitions from stm32xxx.h file, generates a modern C++ definition
Works on a specified device, the output is a class. Does not use any macro, which is 
not compatible with modern C++. 
# Example:
Generate-LLdevice.ps1 -SourceFile = "./stm32h730xx.h" -DeviceName UART
