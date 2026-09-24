# Shared test utilities library (static). Common fixtures/helpers live here
# and are linked by every module's test target.
file(GLOB TEST_COMMON_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp)
add_library(${PROJECT_NAME}_test_common STATIC ${TEST_COMMON_SOURCES})
target_include_directories(${PROJECT_NAME}_test_common PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(${PROJECT_NAME}_test_common PUBLIC
  ${PROJECT_NAME}::${PROJECT_NAME}_lib GTest::gtest)
add_library(${PROJECT_NAME}::test_common ALIAS ${PROJECT_NAME}_test_common)
