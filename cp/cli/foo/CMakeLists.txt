# cli/foo: demo CLI tool linking the shared cli_common library.
file(GLOB CLI_FOO_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/*.cpp)
add_executable(${PROJECT_NAME}_cli_foo ${CLI_FOO_SOURCES})
target_link_libraries(${PROJECT_NAME}_cli_foo PRIVATE ${PROJECT_NAME}::cli_common)
