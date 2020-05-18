project(libobs-metal)

find_library(METAL Metal)
include_directories(${METAL})

set(libobs-metal_PLATFORM_DEPS
	${METAL})

add_definitions(-DLIBOBS_EXPORTS)

set(libobs-metal_SOURCES
	metal-subsystem.mm
	metal-shader.mm
	metal-device.mm)

set(libobs-metal_HEADERS
	metal-subsystem.hpp
	metal-device.hpp)

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
