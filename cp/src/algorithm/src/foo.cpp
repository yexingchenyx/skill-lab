#include "cp/algorithm/foo.hpp"

namespace CP_NS::algorithm {

int add(int a, int b) { return a + b; }

std::string greet_sum(const std::string& name, int a, int b) {
    // Uses the core module: algorithm depends on core.
    core::Greeter greeter(name);
    return greeter.greet() + " Sum is " + std::to_string(add(a, b)) + ".";
}

}  // namespace CP_NS::algorithm
