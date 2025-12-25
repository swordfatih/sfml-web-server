# cmake/deps/uwebsockets.cmake

if (TARGET uWebSockets)
  return()
endif()

include(FetchContent)

enable_language(C)
enable_language(CXX)

option(UWS_WITH_SSL "Build uWebSockets with OpenSSL (enables uWS::SSLApp)" ON)

# ------------------------
# Fetch uWebSockets WITH its uSockets submodule (version-matched)
# ------------------------
FetchContent_Declare(uwebsockets
  GIT_REPOSITORY https://github.com/uNetworking/uWebSockets.git
  GIT_TAG        v20.74.0
  GIT_SHALLOW    TRUE
  GIT_SUBMODULES "uSockets"
  GIT_SUBMODULES_RECURSE TRUE
)
FetchContent_MakeAvailable(uwebsockets)

# uSockets comes from the uWebSockets submodule
set(USOCKETS_DIR "${uwebsockets_SOURCE_DIR}/uSockets")

if (NOT EXISTS "${USOCKETS_DIR}/src")
  message(FATAL_ERROR "uSockets submodule not present at: ${USOCKETS_DIR}. Make sure submodules were fetched.")
endif()

# ------------------------
# Build uSockets (C + possible C++ helpers)
# ------------------------
file(GLOB_RECURSE USOCKETS_C_SOURCES
  "${USOCKETS_DIR}/src/*.c"
)
file(GLOB_RECURSE USOCKETS_CXX_SOURCES
  "${USOCKETS_DIR}/src/*.cpp"
)

set(USOCKETS_SOURCES ${USOCKETS_C_SOURCES} ${USOCKETS_CXX_SOURCES})

# Remove Apple's GCD backend (not used here)
list(FILTER USOCKETS_SOURCES EXCLUDE REGEX ".*/eventing/gcd\\.c(pp)?$")

# On non-Windows, avoid libuv unless you want it
if (NOT WIN32)
  list(FILTER USOCKETS_SOURCES EXCLUDE REGEX ".*/eventing/libuv\\.c(pp)?$")
endif()

# If SSL is OFF, exclude OpenSSL backend (if present)
if (NOT UWS_WITH_SSL)
  list(FILTER USOCKETS_SOURCES EXCLUDE REGEX ".*/crypto/openssl\\.c(pp)?$")
endif()

list(REMOVE_DUPLICATES USOCKETS_SOURCES)

add_library(uSockets STATIC ${USOCKETS_SOURCES})
target_include_directories(uSockets PUBLIC "${USOCKETS_DIR}/src")
target_compile_features(uSockets PUBLIC c_std_11 cxx_std_17)

if (UWS_WITH_SSL)
  find_package(OpenSSL REQUIRED)
  target_compile_definitions(uSockets PRIVATE LIBUS_USE_OPENSSL)
  target_link_libraries(uSockets PUBLIC OpenSSL::SSL OpenSSL::Crypto)
else()
  target_compile_definitions(uSockets PRIVATE LIBUS_NO_SSL)
endif()

if (WIN32)
  target_link_libraries(uSockets PUBLIC ws2_32 iphlpapi userenv)

  # uSockets on Windows commonly uses libuv eventing
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(LIBUV REQUIRED libuv)

  target_include_directories(uSockets PUBLIC ${LIBUV_INCLUDE_DIRS})
  target_link_directories(uSockets PUBLIC ${LIBUV_LIBRARY_DIRS})
  target_link_libraries(uSockets PUBLIC ${LIBUV_LIBRARIES})
else()
  find_package(Threads REQUIRED)
  target_link_libraries(uSockets PUBLIC Threads::Threads dl)
endif()

# ------------------------
# uWebSockets (header interface)
# ------------------------
find_package(ZLIB REQUIRED)

add_library(uWebSockets INTERFACE)
target_include_directories(uWebSockets INTERFACE
  "${uwebsockets_SOURCE_DIR}/src"
)
target_link_libraries(uWebSockets INTERFACE
  uSockets
  ZLIB::ZLIB
)

target_compile_definitions(uWebSockets INTERFACE UWS_WITH_ZLIB)
