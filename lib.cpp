#include "lib.h"

// Implement your class methods
std::string generateNewTemp() {
    static unsigned int tempCount = 0;
    std::string tempName = "__temp__" + std::to_string(tempCount++);
    return tempName;
}

std::string generateNewLabel() {
    static unsigned int labelCount = 0;
    std::string labelName = "__label__" + std::to_string(labelCount++);
    return labelName;
}
