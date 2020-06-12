#pragma once

#include <graphics/graphics.h>
#include <graphics/device-exports.h>
#include <iostream>

#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include <QuartzCore/QuartzCore.h>

struct gs_swap_chain {
    NSView *view;
    CAMetalLayer *layer;
    
    gs_swap_chain(gs_device *device, const gs_init_data *data);
};
