project(libobs-metal)

find_library(METAL Metal)
include_directories(${METAL})

set(libobs-metal_PLATFORM_DEPS
	${METAL})

add_definitions(-DLIBOBS_EXPORTS)

set(libobs-metal_SOURCES
	metal-device.mm
	metal-indexbuffer.mm
	metal-rebuild.mm
	metal-samplerstate.mm
	metal-shader.mm
	metal-shaderbuilder.cpp
	metal-shaderprocessor.mm
	metal-stagesurf.mm
	metal-subsystem.mm
	metal-swapchain.mm
	metal-texture2d.mm
	metal-vertexbuffer.mm
	metal-zstencilbuffer.mm)

set(libobs-metal_HEADERS
	metal-shaderprocessor.hpp
	metal-subsystem.hpp)

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
