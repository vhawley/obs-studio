#pragma once

#include <graphics/graphics.h>
#include <graphics/device-exports.h>
#include <graphics/shader-parser.h>

#include <iostream>
#include <vector>

#include <util/base.h>
#include <graphics/matrix4.h>
#include <graphics/graphics.h>
#include <graphics/device-exports.h>

#include <Metal/Metal.h>
#include <MetalKit/MetalKit.h>
#include <QuartzCore/QuartzCore.h>

enum gs_object_type {
    GS_VERTEX_BUFFER,
    GS_INDEX_BUFFER,
    GS_TEXTURE,
    GS_ZSTENCIL_BUFFER,
    GS_STAGE_SURFACE,
    GS_SAMPLER_STATE,
    GS_SHADER,
    GS_SWAP_CHAIN
};

struct gs_object {
    gs_device_t *device;
    gs_object_type obj_type;
    
    inline gs_object(gs_device_t *device, gs_object_type obj_type)
    : device(device),
    obj_type(obj_type) { }
};

struct gs_swap_chain : gs_object {
    NSView *view;
    CAMetalLayer *layer;
    
    gs_swap_chain(gs_device *device, const gs_init_data *data);
};

struct gs_sampler_state : gs_object {
    const gs_sampler_info info;

    MTLSamplerDescriptor  *samplerDesc;
    id<MTLSamplerState>   samplerState;

    void InitSampler();

    inline void Release() {samplerState = nil;}
    inline void Rebuild() {InitSampler();}

    gs_sampler_state(gs_device_t *device, const gs_sampler_info *info);
};

struct ShaderSampler {
    std::string      name;
    gs_sampler_state sampler;

    inline ShaderSampler(const char *name, gs_device_t *device,
            gs_sampler_info *info)
        : name    (name),
          sampler (device, info)
    {
    }
};

struct gs_shader_param {
   const std::string          name;
   const gs_shader_param_type type;
   const int                  arrayCount;

   struct gs_sampler_state    *nextSampler = nullptr;

   uint32_t                   textureID;
   size_t                     pos;

   std::vector<uint8_t>       curValue;
   std::vector<uint8_t>       defaultValue;
   bool                       changed;

   gs_shader_param(shader_var &var, uint32_t &texCounter);
};

struct gs_texture : gs_object {
    uint32_t width;
    uint32_t height;
    uint32_t bytes;
    gs_color_format color_format;
    uint32_t levels;
    const uint8_t **data;
    uint32_t flags;
    gs_texture_type texture_type;
    
    gs_texture(gs_device_t *device, uint32_t width, uint32_t height, gs_color_format color_format, uint32_t levels, const uint8_t **data, uint32_t flags, gs_texture_type texture_type);
};

struct gs_vertex_buffer : gs_object {
    gs_vb_data *data;
    uint32_t flags;
    
    gs_vertex_buffer(gs_device_t *device, struct gs_vb_data *data, uint32_t flags);
};

struct gs_shader : gs_object {
    const char *shader;
    const char *file;
    gs_shader_type shader_type;
    
    gs_shader(gs_device_t *device, const char *shader, const char *file, gs_shader_type shader_type);
};
