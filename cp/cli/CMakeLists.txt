# cli/: CLI tools. cli/common is the shared utilities library; each tool
# lives in its own subdirectory (e.g. foo) and links cli_common.
add_subdirectory(common)
add_subdirectory(foo)
