FetchContent_Declare(googletest URL https://github.com/google/googletest/archive/refs/tags/v1.17.0.zip)
FetchContent_MakeAvailable(googletest)

include(GoogleTest)

set(tests_dir "${CMAKE_SOURCE_DIR}/tests")
set(test_dir "${tests_dir}/unit")

file(GLOB_RECURSE test_sources "${test_dir}/*.cpp")
add_executable(${PROJECT_NAME}_test ${test_sources})
target_link_libraries(${PROJECT_NAME}_test PRIVATE GTest::gtest_main)

if(library_sources)
    target_link_libraries(${PROJECT_NAME}_test PRIVATE ${PROJECT_NAME}_lib)
endif()

file(TO_CMAKE_PATH "${tests_dir}/data" TEST_DATA_DIR_PATH)
target_compile_definitions(${PROJECT_NAME}_test PRIVATE TEST_DATA_DIR="${TEST_DATA_DIR_PATH}")

gtest_discover_tests(${PROJECT_NAME}_test)
