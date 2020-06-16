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
    ${QUARTZCORE}
    ${METAL})

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

add_library(libobs-metal SHARED
	${libobs-metal_SOURCES}
	${libobs-metal_HEADERS})

set_target_properties(libobs-metal
	PROPERTIES
		FOLDER "core"
		OUTPUT_NAME obs-metal
		)

target_link_libraries(libobs-metal
	libobs
	glad
	${libobs-metal_PLATFORM_DEPS})

install_obs_core(libobs-metal)
