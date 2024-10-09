cmake_minimum_required(VERSION 3.26)
project(csharpify-demo)

if(POLICY CMP0091)
  cmake_policy(SET CMP0091 NEW)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 17)

set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "")
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug")
endif()

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    message(STATUS "CMAKE_INSTALL_PREFIX is not set. Default value is '${CMAKE_INSTALL_PREFIX}', will set it to ${CMAKE_SOURCE_DIR}/install")
    set(CMAKE_INSTALL_PREFIX "${CMAKE_SOURCE_DIR}/install" CACHE PATH "Where the app will be installed to" FORCE)
endif()

# Set -DCSHARPIFY_ZIP=[url or local path] to point to a url or local path of a zip of the packaged csharpify
# (created with cmake --preset [coreclr/mono/nativeaot] && cpack --preset [coreclr/mono/nativeaot])
if(NOT CSHARPIFY_ZIP)
  find_package(CSharpify HINTS "${CMAKE_SOURCE_DIR}/../csharpify/install/lib/cmake")
endif()

if(NOT CSharpify_DIR)
  if(NOT CSHARPIFY_ZIP)
    message(FATAL_ERROR "Could not find CSharpify in ../csharpify and CSHARPIFY_ZIP is not set")
  endif()

  # Normalize the path if it's not a url
  if(NOT CSHARPIFY_ZIP MATCHES "^http*")
    cmake_path(ABSOLUTE_PATH CSHARPIFY_ZIP BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" NORMALIZE OUTPUT_VARIABLE CSHARPIFY_ZIP)
  endif()

  message(STATUS "Installing CSharpify from ${CSHARPIFY_ZIP}")

  include(FetchContent)
  FetchContent_Declare(
    CSharpify
    URL "${CSHARPIFY_ZIP}"
  )
  FetchContent_MakeAvailable(CSharpify)
  find_package(CSharpify HINTS "${FETCHCONTENT_BASE_DIR}/csharpify-src/lib/cmake")
endif()

file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/packages")

add_subdirectory("${CMAKE_SOURCE_DIR}/dotnet-deps")

# This must come after including dotnet-deps
include(CSharpifyDotnet)

if(DOTNET_PLATFORM STREQUAL "win")
  # there are two libs, nethost.lib (dynamic) and libnethost.lib (static), and we want the dynamic one
  # the static one forces a static release runtime on all subsequent links and that's annoying
  set(NETHOST "${DOTNET_APPHOST_PATH}/nethost.lib")
endif()

add_subdirectory("${CMAKE_SOURCE_DIR}/src")
set_property(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY VS_STARTUP_PROJECT test)