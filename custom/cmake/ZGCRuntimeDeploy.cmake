# ============================================================================
# ZGC Runtime Deploy (CMake script mode, executed via `cmake -P`)
# Task: A3-20260904-brand-ui-fix (DEF-2). Deploys the Qt/GStreamer runtime next
# to the freshly built executable after each build so a clean build tree can be
# launched directly without a manual windeployqt pass (ZFYZ-11 leftover #1).
# Upstream deploys on Windows only during install/CPack (research-fix.md 2.1);
# this script is a build-tree dev convenience and does not affect install rules
# or packaging.
#
# Input variables (passed by the POST_BUILD hook in custom/CMakeLists.txt):
#   WINDEPLOYQT_EXECUTABLE - path to windeployqt (from the Qt6::windeployqt target)
#   EXECUTABLE             - path of the just-built executable
#   OUTPUT_DIR             - directory receiving the deployed runtime
#   CONFIGURATION          - build configuration (Debug/Release/...)
#   SOURCE_ROOT            - CMAKE_SOURCE_DIR (locates the CPM GStreamer cache)
#
# Failure policy: any missing piece warns and skips; never fails the build.
# ============================================================================

cmake_minimum_required(VERSION 3.25)

# ---------------------------------------------------------------- windeployqt
if(NOT WINDEPLOYQT_EXECUTABLE)
    message(WARNING "ZGC deploy: WINDEPLOYQT_EXECUTABLE not provided, skipping windeployqt step.")
elseif(NOT EXECUTABLE)
    message(WARNING "ZGC deploy: EXECUTABLE not provided, skipping windeployqt step.")
elseif(NOT EXISTS "${WINDEPLOYQT_EXECUTABLE}")
    message(WARNING "ZGC deploy: windeployqt not found at '${WINDEPLOYQT_EXECUTABLE}', skipping windeployqt step.")
elseif(NOT EXISTS "${EXECUTABLE}")
    message(WARNING "ZGC deploy: executable not found at '${EXECUTABLE}', skipping windeployqt step.")
else()
    if(CONFIGURATION STREQUAL "Debug")
        set(zgc_wqt_config --debug)
    else()
        set(zgc_wqt_config --release)
    endif()
    # QML scan source: the plain src/ tree (ZFYZ-11 smoke deployment used it
    # successfully). No -no-quick-import here: that option belongs to the
    # CMake-managed install-time deploy script, not a direct POST_BUILD run.
    execute_process(
        COMMAND "${WINDEPLOYQT_EXECUTABLE}" ${zgc_wqt_config} --qmldir "${SOURCE_ROOT}/src" "${EXECUTABLE}"
        RESULT_VARIABLE zgc_wqt_result
        OUTPUT_VARIABLE zgc_wqt_output
        ERROR_VARIABLE zgc_wqt_error
    )
    if(NOT zgc_wqt_result EQUAL 0)
        message(WARNING "ZGC deploy: windeployqt failed with exit code ${zgc_wqt_result}. stdout/stderr:\n${zgc_wqt_output}\n${zgc_wqt_error}")
    else()
        message(STATUS "ZGC deploy: windeployqt ${zgc_wqt_config} OK for '${EXECUTABLE}'")
    endif()
endif()

# ------------------------------------------------------------------ GStreamer
# Glob the versioned CPM cache roots directly: GStreamer_ROOT_DIR is not
# reliably visible from the custom/ scope on a fresh configure
# (research-fix.md 2.3.4). Globbing picks up SDK version bumps automatically.
file(GLOB zgc_gst_dlls
    "${SOURCE_ROOT}/.cache/CPM/gstreamer-win-*/sdk/bin/*.dll"
)

if(NOT OUTPUT_DIR)
    message(WARNING "ZGC deploy: OUTPUT_DIR not provided, skipping GStreamer DLL copy.")
elseif(NOT zgc_gst_dlls)
    message(WARNING "ZGC deploy: no GStreamer DLLs found under '${SOURCE_ROOT}/.cache/CPM/gstreamer-win-*/sdk/bin', skipping GStreamer DLL copy.")
else()
    list(LENGTH zgc_gst_dlls zgc_gst_count)
    set(zgc_gst_failed 0)
    foreach(zgc_dll IN LISTS zgc_gst_dlls)
        get_filename_component(zgc_dll_name "${zgc_dll}" NAME)
        file(COPY_FILE "${zgc_dll}" "${OUTPUT_DIR}/${zgc_dll_name}" ONLY_IF_DIFFERENT RESULT zgc_copy_result)
        if(zgc_copy_result)
            math(EXPR zgc_gst_failed "${zgc_gst_failed} + 1")
            message(WARNING "ZGC deploy: failed to copy '${zgc_dll_name}': ${zgc_copy_result}")
        endif()
    endforeach()
    if(zgc_gst_failed EQUAL 0)
        message(STATUS "ZGC deploy: ${zgc_gst_count} GStreamer DLL(s) ensured in '${OUTPUT_DIR}'")
    else()
        message(WARNING "ZGC deploy: ${zgc_gst_failed} of ${zgc_gst_count} GStreamer DLL(s) failed to copy.")
    endif()
endif()
