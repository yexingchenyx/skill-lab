#include <gtest/gtest.h>

#include "cp/algorithm/foo.hpp"

// Tests for the `algorithm` module.
TEST(Algorithm, Add) {
    EXPECT_EQ(CP_NS::algorithm::add(1, 2), 3);
}

TEST(Algorithm, GreetSum) {
    // algorithm depends on core, so core types are usable here.
    EXPECT_EQ(CP_NS::algorithm::greet_sum("world", 1, 2),
              "Hello, world! Sum is 3.");
}
