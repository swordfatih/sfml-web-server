cmake_minimum_required(VERSION 3.28)
project(sfml-web-server LANGUAGES CXX)

include(FetchContent)
include(CTest)
enable_testing()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ------------------------
# Dependencies
# ------------------------
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/deps")
include(uwebsockets)

set(FETCHCONTENT_UPDATES_DISCONNECTED ON)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build everything statically" FORCE)
set(SFML_STATIC_LIBRARIES TRUE CACHE BOOL "Use SFML as static library")
set(SFML_STATIC TRUE)

FetchContent_Declare(sfml GIT_REPOSITORY https://github.com/SFML/SFML.git GIT_TAG 3.0.2 GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(sfml)

# ------------------------
# Configuration function
# ------------------------
function(configure_target target)
    target_include_directories(${target} PUBLIC ${CMAKE_SOURCE_DIR}/include)
    target_link_libraries(${target} PUBLIC SFML::Graphics SFML::Network SFML::Audio uWebSockets)
    target_compile_options(${target} PUBLIC -Wall -Wextra -Wpedantic -Wno-unused-but-set-variable -Wno-unused-parameter)
    target_link_options(${target} PUBLIC -static -static-libgcc -static-libstdc++)
endfunction()

# ------------------------
# Library
# ------------------------
file(GLOB_RECURSE library_sources "${CMAKE_SOURCE_DIR}/${PROJECT_NAME}/src/*.cpp")
list(FILTER library_sources EXCLUDE REGEX ".*/main\\.cpp$")

if(library_sources)
    add_library(${PROJECT_NAME}_lib STATIC ${library_sources})
    configure_target(${PROJECT_NAME}_lib)
endif()

# ------------------------
# Executable
# ------------------------
add_executable(${PROJECT_NAME} ${CMAKE_SOURCE_DIR}/src/main.cpp)
set_target_properties(${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/runtime)

if(TARGET ${PROJECT_NAME}_lib)
  target_link_libraries(${PROJECT_NAME} PUBLIC ${PROJECT_NAME}_lib)
else()
    configure_target(${PROJECT_NAME})
endif()

# ------------------------
# Tests
# ------------------------
add_subdirectory(tests/unit)
