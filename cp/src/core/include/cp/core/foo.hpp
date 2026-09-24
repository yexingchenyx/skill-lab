#pragma once

#include <string>

#include "cp/config.h"

namespace CP_NS::core {

/// Sample class for the `core` module.
class CP_API Greeter {
public:
    explicit Greeter(std::string name);
    std::string greet() const;

private:
    std::string name_;
};

}  // namespace CP_NS::core
