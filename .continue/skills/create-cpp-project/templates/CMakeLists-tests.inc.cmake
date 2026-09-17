# Enable tests. Google Test is fetched/loaded via cmake/thirdparty.cmake
# when <PROJECT_NAME_UPPER>_BUILD_TESTS is ON.
#
# Test layout: tests/<module>/ holds the tests for each module
# (mirrors src/<module>/include/<project-name>/<module>/). Each module's
# tests are added via add_subdirectory from tests/CMakeLists.txt.
if(<PROJECT_NAME_UPPER>_BUILD_TESTS)
  # enable_testing() at the top level so the top-level build dir gets a
  # CTestTestfile.cmake and `ctest --test-dir build` discovers all tests
  # registered in subdirectories.
  enable_testing()
  add_subdirectory(tests)
endif()
