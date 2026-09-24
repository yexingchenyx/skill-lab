#pragma once

#include <string>

#include "cp/config.h"
#include "cp/core/foo.hpp"

namespace CP_NS::algorithm {

/// Sample utility for the `algorithm` module.
/// Depends on the `core` module (e.g. uses core::Greeter).
CP_API std::string greet_sum(const std::string& name, int a, int b);

CP_API int add(int a, int b);

}  // namespace CP_NS::algorithm
