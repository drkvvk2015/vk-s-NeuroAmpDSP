cmake_minimum_required(VERSION 3.22.1)
project(neuroamp_dsp)

add_library(
    neuroamp_dsp
    SHARED
    dsp_engine.cpp
)

find_library(log-lib log)

target_link_libraries(
    neuroamp_dsp
    ${log-lib}
)
