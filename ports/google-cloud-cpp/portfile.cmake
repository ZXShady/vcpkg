vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO googleapis/google-cloud-cpp
    REF "v${VERSION}"
    SHA512 a482008c81d12ffd6ec97b58fc25677f93ac59338e7092c28d2d3bace2f5263d575827b9837bb3413b3078bf5bb4feda4410eeeb269b888aa05f056ced42175f
    HEAD_REF main
    PATCHES fix-googleapis-download.patch
)

# On update, update REF according to $/cmake/GoogleapisConfig.cmake 's
# set(_GOOGLE_CLOUD_CPP_GOOGLEAPIS_COMMIT_SHA
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH_GOOGLEAPIS
    REPO googleapis/googleapis
    REF 079e5305050859d0e3a8c0768611283ee4863c07
    SHA512 c02ce31b4a2c80596a6c786a49b59f42d6b104e911b8e10f2548768ed48d708fc46308aecf04611c62512a968d9c31e9d0a73f921fcf5d1ab533e5ce8d9cf72c
    HEAD_REF master
)

if(NOT EXISTS "${SOURCE_PATH}/external/googleapis/src")
    file(MAKE_DIRECTORY "${SOURCE_PATH}/external/googleapis/src")
    file(RENAME "${SOURCE_PATH_GOOGLEAPIS}" "${SOURCE_PATH}/external/googleapis/src/googleapis_download")
endif()

if ("grpc-common" IN_LIST FEATURES)
    vcpkg_add_to_path(PREPEND "${CURRENT_HOST_INSTALLED_DIR}/tools/grpc")
endif ()

set(GOOGLE_CLOUD_CPP_ENABLE "${FEATURES}")
list(REMOVE_ITEM GOOGLE_CLOUD_CPP_ENABLE "core")
# This feature does not exist, but allows us to simplify the vcpkg.json
# file.
list(REMOVE_ITEM GOOGLE_CLOUD_CPP_ENABLE "grpc-common")
list(REMOVE_ITEM GOOGLE_CLOUD_CPP_ENABLE "rest-common")
list(REMOVE_ITEM GOOGLE_CLOUD_CPP_ENABLE "googleapis")
# google-cloud-cpp uses dialogflow_cx and dialogflow_es. Underscores
# are invalid in `vcpkg` features, we use dashes (`-`) as a separator
# for the `vcpkg` feature name, and convert it here to something that
# `google-cloud-cpp` would like.
if ("dialogflow-cx" IN_LIST FEATURES)
    list(REMOVE_ITEM GOOGLE_CLOUD_CPP_ENABLE "dialogflow-cx")
    list(APPEND GOOGLE_CLOUD_CPP_ENABLE "dialogflow_cx")
endif ()
if ("dialogflow-es" IN_LIST FEATURES)
    list(REMOVE_ITEM GOOGLE_CLOUD_CPP_ENABLE "dialogflow-es")
    list(APPEND GOOGLE_CLOUD_CPP_ENABLE "dialogflow_es")
endif ()
if ("storage-grpc" IN_LIST FEATURES)
    list(REMOVE_ITEM GOOGLE_CLOUD_CPP_ENABLE "storage-grpc")
    list(APPEND GOOGLE_CLOUD_CPP_ENABLE "storage_grpc")
endif ()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        "-DGOOGLE_CLOUD_CPP_ENABLE=${GOOGLE_CLOUD_CPP_ENABLE}"
        -DGOOGLE_CLOUD_CPP_ENABLE_MACOS_OPENSSL_CHECK=OFF
        -DGOOGLE_CLOUD_CPP_ENABLE_WERROR=OFF
        -DGOOGLE_CLOUD_CPP_ENABLE_CCACHE=OFF
        -DGOOGLE_CLOUD_CPP_ENABLE_EXAMPLES=OFF
        -DBUILD_TESTING=OFF
        -DGOOGLE_CLOUD_CPP_WITH_MOCKS=OFF
)

vcpkg_cmake_install()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

function (google_cloud_cpp_cmake_config_fixup library)
    string(REPLACE "experimental-" "" library "${library}")
    string(REPLACE "-" "_" library "${library}")
    set(config_path "lib/cmake/google_cloud_cpp_${library}")
    # If the library exists and is installed, tell vcpkg about it.
    if(NOT IS_DIRECTORY "${CURRENT_PACKAGES_DIR}/${config_path}")
        return()
    endif()
    vcpkg_cmake_config_fixup(PACKAGE_NAME "google_cloud_cpp_${library}"
                             CONFIG_PATH "${config_path}"
                             DO_NOT_DELETE_PARENT_CONFIG_PATH)
endfunction ()

foreach(feature IN LISTS GOOGLE_CLOUD_CPP_ENABLE)
    google_cloud_cpp_cmake_config_fixup(${feature})
    google_cloud_cpp_cmake_config_fixup(${feature}_mocks)
endforeach()

# These packages are automatically installed depending on what features are
# enabled.
foreach(feature common compute_protos googleapis grpc_utils iam_v2 logging_type rest_internal rest_protobuf_internal)
    google_cloud_cpp_cmake_config_fixup(${feature})
endforeach()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib/cmake"
                    "${CURRENT_PACKAGES_DIR}/debug/lib/cmake"
                    "${CURRENT_PACKAGES_DIR}/debug/share")
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)

vcpkg_copy_pdbs()
