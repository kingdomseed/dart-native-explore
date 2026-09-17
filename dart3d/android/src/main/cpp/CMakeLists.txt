cmake_minimum_required(VERSION 3.22.1)
project(dart3d_jni CXX)

add_library(dart3d_jni SHARED dart3d_jni.cpp)

find_library(log-lib log)
target_link_libraries(dart3d_jni ${log-lib})
