# Tests for the core module.
file(GLOB CORE_TEST_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)
add_executable(${PROJECT_NAME}_core_tests ${CORE_TEST_SOURCES})
target_link_libraries(${PROJECT_NAME}_core_tests
  PRIVATE ${PROJECT_NAME}::test_common GTest::gtest_main)

include(GoogleTest)
gtest_discover_tests(${PROJECT_NAME}_core_tests)
