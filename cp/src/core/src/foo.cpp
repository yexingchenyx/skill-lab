#include "cp/core/foo.hpp"

namespace CP_NS::core {

Greeter::Greeter(std::string name) : name_(std::move(name)) {}

std::string Greeter::greet() const {
    return "Hello, " + name_ + "!";
}

}  // namespace CP_NS::core
