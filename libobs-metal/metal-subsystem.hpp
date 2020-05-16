#pragma once

#include <graphics/graphics.h>
#include <graphics/device-exports.h>
#include <iostream>

#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>

struct gs_device {
    id<MTLDevice> device;
};
