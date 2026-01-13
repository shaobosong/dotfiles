cmake_minimum_required(VERSION 3.25)
project(dummy C)

include(CMakePrintSystemInformation)

get_cmake_property(_vars VARIABLES)
foreach(v ${_vars})
  message(STATUS "${v} = [${${v}}]")
endforeach()
