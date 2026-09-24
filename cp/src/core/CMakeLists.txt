# core module: self-contained library target (no module dependencies).
# Sources in src/, headers in include/cp/core/.
file(GLOB CORE_SOURCES CONFIGURE_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp)
# Dynamic vs static is controlled by BUILD_SHARED_LIBS (set in CMakePresets:
# ON in base, OFF in *-static presets).
add_library(${PROJECT_NAME}_core ${CORE_SOURCES})
target_include_directories(${PROJECT_NAME}_core
  PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include ${CP_CONFIG_DIR})

# Unified export macro: all modules share CP_API from config.h.
# CP_EXPORTS (PRIVATE) marks "building this library";
# CP_STATIC_DEFINE (static builds) disables dllexport/dllimport.
target_compile_definitions(${PROJECT_NAME}_core PRIVATE CP_EXPORTS)
if(NOT BUILD_SHARED_LIBS)
  target_compile_definitions(${PROJECT_NAME}_core PUBLIC CP_STATIC_DEFINE)
endif()
# Namespaced alias: consumers link cp::core
add_library(${PROJECT_NAME}::core ALIAS ${PROJECT_NAME}_core)
