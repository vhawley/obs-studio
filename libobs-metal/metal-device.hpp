#pragma once

#include <graphics/graphics.h>
#include <graphics/device-exports.h>
#include <iostream>

#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>

struct gs_device {
    id<MTLDevice> device;
    id<MTLBuffer> buffer;
    id<MTLRenderPipelineState> render_pipeline_state;
    id<MTLCommandQueue> command_queue;
    
    uint32_t device_index;
    gs_swap_chain *current_swap_chain;
    gs_vertex_buffer *current_vertex_buffer;
    gs_index_buffer *current_index_buffer;
    gs_texture *current_textures[GS_MAX_TEXTURES];
    gs_sampler_state *current_samplers[GS_MAX_TEXTURES];
    gs_shader *current_vertex_shader;
    gs_shader *current_pixel_shader;

    MTLRenderPassDescriptor *render_pass_descriptor;
    MTLRenderPipelineDescriptor *render_pipeline_descriptor;
    
    gs_device(uint32_t adapterIdx);
};

