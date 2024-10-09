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

find_package(CSharpify HINTS "${CMAKE_SOURCE_DIR}/../csharpify/install/lib/cmake")

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