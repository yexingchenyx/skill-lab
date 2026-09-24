# Tests for the algorithm module.
file(GLOB ALGORITHM_TEST_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)
add_executable(${PROJECT_NAME}_algorithm_tests ${ALGORITHM_TEST_SOURCES})
target_link_libraries(${PROJECT_NAME}_algorithm_tests
  PRIVATE ${PROJECT_NAME}::test_common GTest::gtest_main)

include(GoogleTest)
gtest_discover_tests(${PROJECT_NAME}_algorithm_tests)
