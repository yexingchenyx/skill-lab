# CLI11 command-line parsing (always included).
# Strategy: prefer a locally installed CLI11 (find_package);
# fall back to FetchContent only if not found.

find_package(CLI11 QUIET)

if(NOT CLI11_FOUND)
  message(STATUS "CLI11 not found locally — fetching via FetchContent")
  include(FetchContent)
  # FETCHCONTENT_BASE_DIR is set in cmake/thirdparty.cmake (dep_installed/,
  # outside build/) — downloads survive `rm -rf build`.
  FetchContent_Declare(
    cli11
    URL https://github.com/CLIUtils/CLI11/archive/refs/tags/v2.4.2.zip
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
  )
  FetchContent_MakeAvailable(cli11)
endif()

# Final summary: version and location of the CLI11 actually used.
if(TARGET CLI11::CLI11)
  get_target_property(_cli11_inc CLI11::CLI11 INTERFACE_INCLUDE_DIRECTORIES)
  get_target_property(_cli11_type CLI11::CLI11 TYPE)
  if(CLI11_FOUND)
    set(_cli11_src "vcpkg/local install")
  else()
    set(_cli11_src "built from source (FetchContent)")
  endif()
  if(CLI11_VERSION)
    set(_cli11_ver "${CLI11_VERSION}")
  else()
    set(_cli11_ver "2.4.2")
  endif()
  if(_cli11_type STREQUAL "STATIC_LIBRARY" OR _cli11_type STREQUAL "SHARED_LIBRARY")
    set(_cli11_loc "target: ${_cli11_src}")
  else()
    get_target_property(_cli11_loc CLI11::CLI11 LOCATION)
    if(_cli11_loc MATCHES "NOTFOUND")
      set(_cli11_loc "target: ${_cli11_src} (interface)")
    endif()
  endif()
  message(STATUS "CLI11 version: ${_cli11_ver} (${_cli11_src}) | include: ${_cli11_inc} | ${_cli11_loc}")
endif()

# CLI11 provides the namespaced target CLI11::CLI11 — nothing more to alias.
# Consumers link: target_link_libraries(<target> PRIVATE CLI11::CLI11)
