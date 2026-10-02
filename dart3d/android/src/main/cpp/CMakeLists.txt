cmake_minimum_required(VERSION 3.22.1)
project(dart3d_jni CXX)

add_library(dart3d_jni SHARED dart3d_jni.cpp)

# dart3d_jni.cpp mirrors two Filament structs to read frame timings.
# The mirror was checked against this version only.
if(DART3D_FILAMENT_VERSION STREQUAL "1.71.6")
    target_compile_definitions(dart3d_jni PRIVATE D3_FILAMENT_FRAME_INFO=1)
endif()

find_library(log-lib log)
target_link_libraries(dart3d_jni ${log-lib})
