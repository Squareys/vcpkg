vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mosra/magnum-plugins
    REF v2020.06
    SHA512 3c11c2928bfc9d04c1ad64f72b6ffac6cf80a1ef3aacc5d0486b9ad955cf4f6ea6d5dcb3846dc5d73f64ec522a015eafb997f62c79ad7ff91169702341f23af0
    HEAD_REF master
    PATCHES
        001-tools-path.patch
)

if(basisimporter IN_LIST FEATURES OR basisimageconverter IN_LIST FEATURES)
    # Bundle Basis Universal, a commit that's before the UASTC support (which
    # is not implemented yet). The repo has big unrequired files in its
    # history, so we're downloading just a snapshot instead of a git clone.
    vcpkg_download_distfile(
        _BASIS_UNIVERSAL_PATCHES
        URLS "https://github.com/BinomialLLC/basis_universal/commit/e9c55faac7745ebf38d08cd3b4f71aaf542f8191.diff"
        FILENAME "e9c55faac7745ebf38d08cd3b4f71aaf542f8191.patch"
    SHA512 3c11c2928bfc9d04c1ad64f72b6ffac6cf80a1ef3aacc5d0486b9ad955cf4f6ea6d5dcb3846dc5d73f64ec522a015eafb997f62c79ad7ff91169702341f23af0
    )
    set(_BASIS_VERSION "8565af680d1bd2ad56ab227ca7d96c56dfbe93ed")
    vcpkg_download_distfile(
        _BASIS_UNIVERSAL_ARCHIVE
        URLS "https://github.com/BinomialLLC/basis_universal/archive/${_BASIS_VERSION}.tar.gz"
        FILENAME "basis-universal-${_BASIS_VERSION}.tar.gz"
    SHA512 3c11c2928bfc9d04c1ad64f72b6ffac6cf80a1ef3aacc5d0486b9ad955cf4f6ea6d5dcb3846dc5d73f64ec522a015eafb997f62c79ad7ff91169702341f23af0
    )
    vcpkg_extract_source_archive_ex(
        OUT_SOURCE_PATH _BASIS_UNIVERSAL_SOURCE
        ARCHIVE ${_BASIS_UNIVERSAL_ARCHIVE}
        WORKING_DIRECTORY "${SOURCE_PATH}/src/external"
        PATCHES
            ${_BASIS_UNIVERSAL_PATCHES})
    # Remove potentially cached directory which would cause renaming to fail
    file(REMOVE_RECURSE "${SOURCE_PATH}/src/external/basis-universal")
    # Rename the output folder so that magnum auto-detects it
    file(RENAME ${_BASIS_UNIVERSAL_SOURCE} "${SOURCE_PATH}/src/external/basis-universal")
endif()

if(meshoptimizersceneconverter IN_LIST FEATURES)
    # Bundle meshoptimizer 0.14 + a commit that fixes the build on old Apple
    # Clang versions: https://github.com/zeux/meshoptimizer/pull/130
    vcpkg_download_distfile(
        _MESHOPTIMIZER_ARCHIVE
        URLS "https://github.com/zeux/meshoptimizer/archive/97c52415c6d29f297a76482ddde22f739292446d.tar.gz"
        FILENAME "meshoptimizer.tar.gz"
    SHA512 3c11c2928bfc9d04c1ad64f72b6ffac6cf80a1ef3aacc5d0486b9ad955cf4f6ea6d5dcb3846dc5d73f64ec522a015eafb997f62c79ad7ff91169702341f23af0
    )
    vcpkg_extract_source_archive_ex(
        OUT_SOURCE_PATH _MESHOPTIMIZER_SOURCE
        ARCHIVE ${_MESHOPTIMIZER_ARCHIVE}
        WORKING_DIRECTORY "${SOURCE_PATH}/src/external")
    # Remove potentially cached directory which would cause renaming to fail
    file(REMOVE_RECURSE "${SOURCE_PATH}/src/external/meshoptimizer")
    # Rename the output folder so that magnum auto-detects it
    file(RENAME ${_MESHOPTIMIZER_SOURCE} "${SOURCE_PATH}/src/external/meshoptimizer")
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL static)
    set(BUILD_PLUGINS_STATIC 1)
else()
    set(BUILD_PLUGINS_STATIC 0)
endif()

set(_COMPONENTS "")
# Generate cmake parameters from feature names
foreach(_feature IN LISTS ALL_FEATURES)
    # Uppercase the feature name and replace "-" with "_"
    string(TOUPPER "${_feature}" _FEATURE)
    string(REPLACE "-" "_" _FEATURE "${_FEATURE}")

    # Final feature is empty, ignore it
    if(_feature)
        list(APPEND _COMPONENTS ${_feature} WITH_${_FEATURE})
    endif()
endforeach()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS ${_COMPONENTS})

vcpkg_configure_cmake(
    SOURCE_PATH ${SOURCE_PATH}
    PREFER_NINJA # Disable this option if project cannot be built with Ninja
    OPTIONS
        ${FEATURE_OPTIONS}
        -DBUILD_STATIC=${BUILD_PLUGINS_STATIC}
        -DBUILD_PLUGINS_STATIC=${BUILD_PLUGINS_STATIC}
        -DMAGNUM_PLUGINS_DEBUG_DIR=${CURRENT_INSTALLED_DIR}/debug/bin/magnum-d
        -DMAGNUM_PLUGINS_RELEASE_DIR=${CURRENT_INSTALLED_DIR}/bin/magnum
)

vcpkg_install_cmake()

# Debug includes and share are the same as release
file(REMOVE_RECURSE
    ${CURRENT_PACKAGES_DIR}/debug/include
    ${CURRENT_PACKAGES_DIR}/debug/share)

# Clean up empty directories, if not building anything.
# FEATURES may only contain "core", but that does not build anything.
if(NOT FEATURES OR FEATURES STREQUAL "core")
    file(REMOVE_RECURSE
        ${CURRENT_PACKAGES_DIR}/bin
        ${CURRENT_PACKAGES_DIR}/lib
        ${CURRENT_PACKAGES_DIR}/debug)
    set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL static)
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/bin)
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/bin)
    # move plugin libs to conventional place
    file(GLOB_RECURSE LIB_TO_MOVE ${CURRENT_PACKAGES_DIR}/lib/magnum/*)
    file(COPY ${LIB_TO_MOVE} DESTINATION ${CURRENT_PACKAGES_DIR}/lib)
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/lib/magnum)
    file(GLOB_RECURSE LIB_TO_MOVE_DBG ${CURRENT_PACKAGES_DIR}/debug/lib/magnum/*)
    file(COPY ${LIB_TO_MOVE_DBG} DESTINATION ${CURRENT_PACKAGES_DIR}/debug/lib)
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/lib/magnum)
else()
    set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/lib/magnum)
    file(REMOVE_RECURSE ${CURRENT_PACKAGES_DIR}/debug/lib/magnum-d)
endif()

# Handle copyright
file(COPY ${SOURCE_PATH}/COPYING DESTINATION ${CURRENT_PACKAGES_DIR}/share/magnum-plugins)
file(RENAME ${CURRENT_PACKAGES_DIR}/share/magnum-plugins/COPYING ${CURRENT_PACKAGES_DIR}/share/magnum-plugins/copyright)

vcpkg_copy_pdbs()
