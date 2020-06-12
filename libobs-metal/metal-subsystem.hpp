#pragma once

#include <graphics/graphics.h>
#include <graphics/device-exports.h>
#include <iostream>
#include <vector>

#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include <QuartzCore/QuartzCore.h>

struct gs_swap_chain {
    NSView *view;
    CAMetalLayer *layer;
    
    gs_swap_chain(gs_device *device, const gs_init_data *data);
};

struct gs_texture {
    gs_device_t *device;
    uint32_t width;
    uint32_t height;
    uint32_t bytes;
    gs_color_format color_format;
    uint32_t levels;
    const uint8_t **data;
    uint32_t flags;
    
    gs_texture(gs_device_t *device, uint32_t width, uint32_t height, gs_color_format color_format, uint32_t levels, const uint8_t **data, uint32_t flags);
};
