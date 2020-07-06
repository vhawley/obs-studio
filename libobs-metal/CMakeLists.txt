project(libobs-metal)

find_library(APPKIT AppKit)
mark_as_advanced(APPKIT)
include_directories(${APPKIT})

find_library(QUARTZCORE QuartzCore)
mark_as_advanced(QUARTZCORE)
include_directories(${QUARTZCORE})

find_library(METAL Metal)
mark_as_advanced(METAL)
include_directories(${METAL})

set(libobs-metal_PLATFORM_DEPS
	${APPKIT}
	${QUARTZCORE})

set(libobs-metal_PLATFORM_DEPS_WEAK
	Metal)

add_definitions(-DLIBOBS_EXPORTS)

set(libobs-metal_SOURCES
	metal-subsystem.mm
	metal-shader.mm
    metal-texture.mm
    metal-stagesurface.mm
    metal-vertexbuffer.mm
    metal-indexbuffer.mm
    metal-zstencilbuffer.mm
    metal-samplerstate.mm
    metal-swapchain.mm
    metal-shaderprocessor.mm
    metal-shaderbuilder.cpp)

set(libobs-metal_HEADERS
	metal-subsystem.hpp
    metal-shaderprocessor.hpp)

add_library(libobs-metal MODULE
	${libobs-metal_SOURCES}
	${libobs-metal_HEADERS})

set_target_properties(libobs-metal
	PROPERTIES
		OUTPUT_NAME libobs-metal
		PREFIX ""
		FOLDER "core"
		XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES)

target_compile_options(libobs-metal
	PUBLIC
		-msse
		-msse2
		-msse3
		-msse4.1
		-msse4.2)
target_link_libraries(libobs-metal
	PRIVATE
		${libobs-metal_PLATFORM_DEPS}
	PUBLIC
		libobs)
foreach(FRAMEWORK ${libobs-metal_PLATFORM_DEPS_WEAK})
	target_link_libraries(libobs-metal
		PRIVATE
			"-weak_framework ${FRAMEWORK}")
endforeach()

install_obs_core(libobs-metal)
