cmake_minimum_required(VERSION 3.26)
project(test)

# Configuring paths and file lists for the dotnet build and publish steps
cmake_path(APPEND PROJECT_SOURCE_DIR "main.csproj" OUTPUT_VARIABLE CSPROJ)
cmake_path(GET CSPROJ STEM ASSEMBLYNAME)
set(ASSEMBLYNAME "${ASSEMBLYNAME}" CACHE STRING "Assembly name")

configure_file("${CMAKE_CURRENT_LIST_DIR}/config.h.in" config.h)

set(publish_args "")
set(publish_dir "${PROJECT_BINARY_DIR}/publish")
set(bin_dir "${CMAKE_BINARY_DIR}")
set(bundle_dir "${CMAKE_BINARY_DIR}/bin")

list(APPEND build_outputs ${ASSEMBLYNAME}.dll ${ASSEMBLYNAME}.pdb)
if(DOTNET_PLATFORM STREQUAL "win" AND DOTNET_RUNTIME STREQUAL "coreclr")
  list(APPEND build_outputs ${ASSEMBLYNAME}.runtimeconfig.json)
endif()

file(GLOB cs_sources "${PROJECT_SOURCE_DIR}/*.cs")

# Run dotnet build
add_custom_command(
  OUTPUT "${PROJECT_BINARY_DIR}/.stamp" ${build_outputs} "${PROJECT_SOURCE_DIR}/generated/exports.g.c"
  COMMAND ${CMAKE_COMMAND} -E env "PATH=${ORIGINAL_PATH}" ${DOTNET} build \"${CSPROJ}\" --nologo -c $<CONFIG> -o \"${PROJECT_BINARY_DIR}\" /p:UseMonoRuntime=$<IF:$<BOOL:${RUNTIME_MONO}>,true,false>
  COMMAND ${CMAKE_COMMAND} -E touch "${PROJECT_BINARY_DIR}/.stamp"
  BYPRODUCTS "${PROJECT_SOURCE_DIR}/generated/dnne.h" "${PROJECT_SOURCE_DIR}/generated/exports.h"
  DEPENDS "Directory.Build.props" "Directory.Build.targets" ${cs_sources} "${CSPROJ}"
)
add_custom_target(build DEPENDS ${build_outputs} "${PROJECT_SOURCE_DIR}/generated/exports.g.c")

# Run dotnet publish
add_custom_command(
  OUTPUT "${publish_dir}/.stamp" "${publish_dir}/${ASSEMBLYNAME}.dll" "${publish_dir}/System.dll"
  COMMAND ${CMAKE_COMMAND} -E env "PATH=${ORIGINAL_PATH}" ${DOTNET} publish \"${CSPROJ}\" ${publish_args} --sc -r ${RID} --nologo -c $<CONFIG> -o \"${publish_dir}\"  /p:UseMonoRuntime=$<IF:$<BOOL:${RUNTIME_MONO}>,true,false>
  COMMAND ${CMAKE_COMMAND} -E touch "${publish_dir}/.stamp"
  DEPENDS "Directory.Build.props" "Directory.Build.targets" ${cs_sources} "${CSPROJ}"
)
add_custom_target(publish DEPENDS "${publish_dir}/${ASSEMBLYNAME}.dll")

if(NOT(DOTNET_PLATFORM STREQUAL "win" AND DOTNET_RUNTIME STREQUAL "coreclr"))
  add_custom_target(link_sdk
    COMMAND ${CMAKE_COMMAND} -E create_symlink "${publish_dir}" "${bin_dir}/$<CONFIG>/sdk"
    DEPENDS "${publish_dir}/System.dll"
  )
  list(APPEND dependencies link_sdk)
endif()

list(APPEND export_sources "${PROJECT_SOURCE_DIR}/generated/exports.g.c")
list(APPEND export_includes "${PROJECT_SOURCE_DIR}/generated")

add_executable(test main.cpp ${export_sources})
target_include_directories(test PRIVATE "${CMAKE_CURRENT_BINARY_DIR}" "${CMAKE_BINARY_DIR}/include" "${DOTNET_INCLUDE_DIRS}" ${export_includes} )
target_compile_definitions(test PRIVATE DNNE_COMPILE_AS_SOURCE DNNE_SELF_CONTAINED_RUNTIME DNNE_ASSEMBLY_NAME=${ASSEMBLYNAME})

if(DOTNET_PLATFORM STREQUAL "win")
  target_link_libraries(test PRIVATE ${NETHOST})
endif()

if(RUNTIME_MONO)
  list(APPEND dependencies csharpify_mono)
  target_link_libraries(test PRIVATE csharpify_mono ${CORECLR})
elseif(RUNTIME_CORECLR)
  list(APPEND dependencies csharpify_coreclr)
  target_link_libraries(test PRIVATE csharpify_coreclr)
  if(NOT DOTNET_PLATFORM STREQUAL "win")
    target_link_libraries(test PRIVATE ${CORECLR})
  endif()
endif()

# On Windows, we need to copy nethost.dll next to the executable
# and have a shared/Microsoft.NETCore.App/${DOTNET_SDK_VERSION} folder
# with the sdk, which comes from ${DOTNET_SDK_PATH}
# coreclr.dll et al from ${DOTNET_LIBRARY_PATH} go into the shared folder
# and hostfxr.dll goes into its own folder (it must be three levels down
# because it's hardcoded to search for the sdk three levels up, it's stupid)
if(DOTNET_PLATFORM STREQUAL "win" AND DOTNET_RUNTIME STREQUAL "coreclr")
  list(APPEND build_outputs
    "${DOTNET_APPHOST_PATH}/nethost.dll"
  )

  foreach(thing ${build_outputs})
    cmake_path(GET thing FILENAME filename)
    list(APPEND bundle_outputs "${bundle_dir}/${CMAKE_BUILD_TYPE}/${filename}")
  endforeach()

  list(APPEND bundle_outputs
    "${bundle_dir}/$<CONFIG>/${PROJECT_NAME}${CMAKE_EXECUTABLE_SUFFIX}"
    "${bundle_dir}/$<CONFIG>/shared/Microsoft.NETCore.App/${DOTNET_SDK_VERSION}/Microsoft.NETCore.App.runtimeconfig.json"
    "${bundle_dir}/$<CONFIG>/shared/Microsoft.NETCore.App/${DOTNET_SDK_VERSION}/hostpolicy.dll"
    "${bundle_dir}/$<CONFIG>/shared/Microsoft.NETCore.App/${DOTNET_SDK_VERSION}/coreclr.dll"
    "${bundle_dir}/$<CONFIG>/shared/host/fxr/hostfxr.dll"
  )
  message(STATUS "OUTPUTS ${bundle_outputs}")

  # Bundle everything into a runnable directory
  add_custom_command(
    OUTPUT  ${bundle_outputs} 
    COMMAND ${CMAKE_COMMAND} -E make_directory "${bundle_dir}/$<CONFIG>"
    COMMAND ${CMAKE_COMMAND} -E copy -t "${bundle_dir}/$<CONFIG>" ${build_outputs} "$<TARGET_FILE:test>"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${bundle_dir}/$<CONFIG>/shared/Microsoft.NETCore.App"
    COMMAND ${CMAKE_COMMAND} -E copy_directory_if_different "${DOTNET_SDK_PATH}" "${bundle_dir}/$<CONFIG>/shared/Microsoft.NETCore.App/${DOTNET_SDK_VERSION}"
    COMMAND ${CMAKE_COMMAND} -E copy -t "${bundle_dir}/$<CONFIG>/shared/Microsoft.NETCore.App/${DOTNET_SDK_VERSION}" "${DOTNET_LIBRARY_PATH}/hostpolicy.dll"
    COMMAND ${CMAKE_COMMAND} -E copy -t "${bundle_dir}/$<CONFIG>/shared/Microsoft.NETCore.App/${DOTNET_SDK_VERSION}" "${DOTNET_LIBRARY_PATH}/hostpolicy.dll" "${DOTNET_LIBRARY_PATH}/hostfxr.dll"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${bundle_dir}/$<CONFIG>/shared/host/fxr"
    COMMAND ${CMAKE_COMMAND} -E copy -t "${bundle_dir}/$<CONFIG>/shared/host/fxr" "${DOTNET_LIBRARY_PATH}/hostfxr.dll"
    COMMAND ${CMAKE_COMMAND} -E copy_directory_if_different "${DOTNET_LIBRARY_PATH}" "${bundle_dir}/$<CONFIG>/shared/Microsoft.NETCore.App/${DOTNET_SDK_VERSION}"
    DEPENDS ${build_outputs} "$<TARGET_FILE:test>"
  )

  add_custom_target(bundle DEPENDS test ${bundle_outputs})
endif()

list(APPEND dependencies packages)

add_dependencies(test ${dependencies})

message(STATUS "deps ${PROJECT_NAME}${CMAKE_EXECUTABLE_SUFFIX}")

add_custom_target(program ALL DEPENDS test bundle)

add_custom_target(run 
  COMMAND "${bundle_dir}/$<CONFIG>/$<TARGET_FILE_NAME:test>"
  DEPENDS program)

set_property(TARGET test PROPERTY VS_DEBUGGER_COMMAND "${bundle_dir}/$<CONFIG>/$<TARGET_FILE_NAME:test>")
set_property(TARGET test PROPERTY VS_DEBUGGER_WORKING_DIRECTORY "${bundle_dir}/$<CONFIG>")

install(DIRECTORY "${bundle_dir}/$<CONFIG>" DESTINATION "${CMAKE_PROJECT_NAME}")
