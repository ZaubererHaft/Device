#Ensure that we have an set HIP_PATH
if(NOT DEFINED HIP_PATH)
    if(NOT DEFINED ENV{HIP_PATH})
        set(HIP_PATH "/opt/rocm/hip" CACHE PATH "Path to which HIP has been installed")
    else()
        set(HIP_PATH $ENV{HIP_PATH} CACHE PATH "Path to which HIP has been installed")
    endif()
endif()

#set the CMAKE_MODULE_PATH for the helper cmake files from HIP
set(CMAKE_MODULE_PATH "${HIP_PATH}/cmake" ${CMAKE_MODULE_PATH})

set(HIP_COMPILER hcc)

find_package(HIP QUIET)
if(HIP_FOUND)
    message(STATUS "Found HIP: " ${HIP_VERSION})
else()
    message(FATAL_ERROR "Could not find HIP. Ensure that HIP is either installed in /opt/rocm/hip or the variable HIP_PATH is set to point to the right location.")
endif()


#Can set different FLAGS for the compilers via HCC_OPTIONS and NVCC_OPTIONS keywords; options for both via HIPCC_OPTIONS
#Set the flags here, use them later
#Only need NVCC at the time no AMD system to deploy to
set(MY_HIPCC)
set(MY_HCC)
if (${HIP_PLATFORM} STREQUAL "nvcc")
    set(MY_NVCC -arch=${COMPUTE_SUB_ARCH}; -dc;)
endif()

set(MY_SOURCE_FILES device.cpp
                    interfaces/hip/Aux.cpp
                    interfaces/hip/Control.cpp
                    interfaces/hip/Copy.cpp
                    interfaces/hip/Internals.cpp
                    interfaces/hip/Memory.cpp
                    interfaces/hip/Streams.cpp
                    algorithms/hip/ArrayManip.cpp
                    algorithms/hip/BatchManip.cpp
                    algorithms/hip/Reduction.cpp
                    algorithms/hip/Debugging.cpp)

set(CMAKE_HIP_CREATE_SHARED_LIBRARY "${HIP_HIPCC_CMAKE_LINKER_HELPER} ${HCC_PATH} <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> <CMAKE_SHARED_LIBRARY_CREATE_CXX_FLAGS> -o <TARGET> <OBJECTS> <LINK_LIBRARIES>")


set_source_files_properties(${MY_SOURCE_FILES} PROPERTIES HIP_SOURCE_PROPERTY_FORMAT 1)

hip_add_library(device SHARED ${MY_SOURCE_FILES} HIPCC_OPTIONS ${MY_HIPCC} HCC_OPTIONS ${MY_HCC} NVCC_OPTIONS ${MY_NVCC})


if (${HIP_PLATFORM} STREQUAL "nvcc")
    set_target_properties(device PROPERTIES LINKER_LANGUAGE HIP)
else()
    target_link_libraries(device PUBLIC ${HIP_PATH}/lib/libamdhip64.so)
endif()