# algorithm module: self-contained library target that depends on core.
# Sources in src/, headers in include/cp/algorithm/.
file(GLOB ALGORITHM_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp)
# Dynamic vs static is controlled by BUILD_SHARED_LIBS (set in CMakePresets:
# ON in base, OFF in *-static presets).
add_library(${PROJECT_NAME}_algorithm ${ALGORITHM_SOURCES})
target_include_directories(${PROJECT_NAME}_algorithm
  PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include ${CP_CONFIG_DIR})
# This module includes headers from core, so it MUST link core (already wired).
target_link_libraries(${PROJECT_NAME}_algorithm PUBLIC ${PROJECT_NAME}::core)

# Unified export macro: all modules share CP_API from config.h.
# CP_EXPORTS (PRIVATE) marks "building this library";
# CP_STATIC_DEFINE (static builds) disables dllexport/dllimport.
target_compile_definitions(${PROJECT_NAME}_algorithm PRIVATE CP_EXPORTS)
if(NOT BUILD_SHARED_LIBS)
  target_compile_definitions(${PROJECT_NAME}_algorithm PUBLIC CP_STATIC_DEFINE)
endif()
# Namespaced alias: consumers link cp::algorithm
add_library(${PROJECT_NAME}::algorithm ALIAS ${PROJECT_NAME}_algorithm)
