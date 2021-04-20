#NOTE: We need the device API to call kernels when using oneAPI
if (TARGET device)
    message("target device has already been added!")
else()
    add_subdirectory(root)
endif()

set(KERNEL_SOURCE_FILES subroutinesONEAPI.cpp)
add_library(${TARGET_NAME} SHARED ${KERNEL_SOURCE_FILES})

target_compile_options(${TARGET_NAME} PRIVATE ${EXTRA_FLAGS} -Wall -Wpedantic -std=c++17 -O3)
target_compile_definitions(${TARGET_NAME} PRIVATE DEVICE_${DEVICE_BACKEND}_LANG REAL_SIZE=${REAL_SIZE_IN_BYTES})

target_include_directories(${TARGET_NAME} PUBLIC root)
target_link_libraries(${TARGET_NAME} PUBLIC device)

if (${DEVICE_BACKEND} STREQUAL "HIPSYCL")
    find_package(hipSYCL CONFIG REQUIRED)
    add_sycl_to_target(TARGET ${TARGET_NAME} SOURCES ${KERNEL_SOURCE_FILES})
else()
    set(CMAKE_CXX_COMPILER dpcpp)
    if("$ENV{PREFERRED_DEVICE_TYPE}" STREQUAL "FPGA")
        target_compile_options(${TARGET_NAME} PRIVATE "-fintelfpga")
        set_target_properties(${TARGET_NAME} PROPERTIES LINK_FLAGS "-fintelfpga -Xshardware")
    elseif("$ENV{PREFERRED_DEVICE_TYPE}" STREQUAL "GPU")
        target_compile_options(${TARGET_NAME} PRIVATE "-fsycl-targets=spir64_gen-unknown-unknown-sycldevice")
        set_target_properties(${TARGET_NAME} PROPERTIES LINK_FLAGS "-fsycl-targets=spir64_gen-unknown-unknown-sycldevice -Xs \"-device ${DEVICE_SUB_ARCH}\"")
    elseif("$ENV{PREFERRED_DEVICE_TYPE}" STREQUAL "CPU")
        target_compile_options(${TARGET_NAME} PRIVATE "-fsycl-targets=spir64_x86_64-unknown-unknown-sycldevice")
        set_target_properties(${TARGET_NAME} PROPERTIES LINK_FLAGS "-fsycl-targets=spir64_x86_64-unknown-unknown-sycldevice -Xs \"-march=${DEVICE_SUB_ARCH}\"")
    else()
        message(WARNING "No device type specified for compilation, AOT and other platform specific details may be disabled")
    endif()
endif()
