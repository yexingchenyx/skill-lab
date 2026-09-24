#include <gtest/gtest.h>

#include "cp/core/foo.hpp"

// Tests for the `core` module.
TEST(Core, Greeter) {
    CP_NS::core::Greeter greeter("world");
    EXPECT_EQ(greeter.greet(), "Hello, world!");
}
