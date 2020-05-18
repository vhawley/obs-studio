#pragma once

#include <graphics/graphics.h>
#include <graphics/device-exports.h>
#include <iostream>

#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>

struct gs_device {
    id<MTLDevice> device;
    id<MTLBuffer> buffer;
    id<MTLRenderPipelineState> renderPipelineState;
    id<MTLCommandQueue> commandQueue;
    
    uint32_t deviceIndex;
    
    MTLRenderPassDescriptor *renderPassDescriptor;
    MTLRenderPipelineDescriptor *renderPipelineDescriptor;
    
    gs_device(uint32_t adapterIdx);
};

