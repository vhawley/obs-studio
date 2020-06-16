#pragma once

#include <graphics/graphics.h>
#include <graphics/device-exports.h>
#include <graphics/shader-parser.h>

#include <iostream>
#include <vector>

#include <util/base.h>
#include <graphics/matrix4.h>

#import <AppKit/NSView.h>
#import <QuartzCore/CoreAnimation.h>
#import <Metal/Metal.h>

using namespace std;

struct gs_device {
    id<MTLDevice> metalDevice;
    id<MTLRenderPipelineState> renderPipelineState;
    id<MTLCommandQueue> commandQueue;
    id<MTLCommandBuffer> commandBuffer;
    
    uint32_t deviceIndex;
    gs_swap_chain *currentSwapChain;
    gs_vertex_buffer *currentVertexBuffer;
    gs_index_buffer *currentIndexBuffer;
    gs_texture *currentTextures[GS_MAX_TEXTURES];
    gs_sampler_state *currentSamplers[GS_MAX_TEXTURES];
    gs_shader *currentVertexShader;
    gs_shader *currentPixelShader;
    
    MTLRenderPassDescriptor *renderPassDescriptor;
    MTLRenderPipelineDescriptor *renderPipelineDescriptor;
    
    gs_device(uint32_t adapterIdx);
};

enum gs_object_type {
    GS_VERTEX_BUFFER,
    GS_INDEX_BUFFER,
    GS_ZSTENCIL_BUFFER,
    GS_TEXTURE,
    GS_STAGE_SURFACE,
    GS_SAMPLER_STATE,
    GS_SHADER,
    GS_SWAP_CHAIN
};

struct gs_object {
    gs_device_t *device;
    gs_object_type objectType;
    
    inline gs_object(gs_device_t *device, gs_object_type objectType)
    : device(device),
    objectType(objectType) { }
};

struct gs_swap_chain : gs_object {
    NSView *view;
    CAMetalLayer *metalLayer;
    
    gs_swap_chain(gs_device *device, const gs_init_data *data);
};

struct gs_sampler_state : gs_object {
    const gs_sampler_info info;
    
    MTLSamplerDescriptor  *samplerDesc;
    id<MTLSamplerState>   samplerState;
    
    void InitSampler();
    
    inline void Release() { samplerState = nil; }
    inline void Rebuild() { InitSampler(); }
    
    gs_sampler_state(gs_device_t *device, const gs_sampler_info *info);
};

struct ShaderSampler {
    string      name;
    gs_sampler_state sampler;
    
    inline ShaderSampler(const char *name, gs_device_t *device,
                         gs_sampler_info *info)
    : name    (name),
    sampler (device, info)
    {
    }
};

struct gs_shader_param {
    const string          name;
    const gs_shader_param_type type;
    const int                  arrayCount;
    
    struct gs_sampler_state    *nextSampler = nullptr;
    
    uint32_t                   textureID;
    size_t                     pos;
    
    vector<uint8_t>       curValue;
    vector<uint8_t>       defaultValue;
    bool                  changed;
    
    gs_shader_param(shader_var &var, uint32_t &texCounter);
};

struct gs_texture : gs_object {
    // Data from application
    uint32_t width;
    uint32_t height;
    uint32_t bytes;
    gs_color_format colorFormat;
    uint32_t levels;
    vector<vector<uint8_t>> data;
    
    // Derived from flags
    bool isRenderTarget;
    bool isDynamic;
    bool isShared;
    bool genMipmaps;
    
    // Texture type
    gs_texture_type textureType;
    
    // Metal properties
    id<MTLTexture> metalTexture;
    MTLTextureDescriptor *metalTextureDescriptor;
    MTLPixelFormat metalPixelFormat;
    
    void GenerateMipmap();
    void BackupTexture(const uint8_t **data);
    void UploadTexture();
    
    void InitTextureDescriptor();
    void RebuildTextureDescriptor();
    
    void InitTexture();
    void RebuildTexture();
    
    gs_texture(gs_device_t *device, uint32_t width, uint32_t height, gs_color_format color_format, uint32_t levels, const uint8_t **data, uint32_t flags, gs_texture_type texture_type);
};

struct gs_vertex_buffer : gs_object {
    gs_vb_data *data;
    uint32_t flags;
    
    gs_vertex_buffer(gs_device_t *device, struct gs_vb_data *data, uint32_t flags);
};

struct gs_index_buffer : gs_object {
    gs_index_type type;
    void *indices;
    size_t num;
    uint32_t flags;
    
    gs_index_buffer(gs_device_t *device, gs_index_type type, void *indices, size_t num, uint32_t flags);
};

struct gs_zstencil_buffer : gs_object {
    uint32_t width;
    uint32_t height;
    gs_zstencil_format zstencil_format;
    
    gs_zstencil_buffer(gs_device_t *device, uint32_t width, uint32_t height, gs_zstencil_format format);
};

struct gs_stage_surface : gs_object {
    uint32_t width;
    uint32_t height;
    gs_color_format color_format;
    
    gs_stage_surface(gs_device_t *device, uint32_t width, uint32_t height, gs_color_format color_format);
};

struct gs_shader : gs_object {
    const char *shader;
    const char *file;
    gs_shader_type shader_type;
    
    gs_shader(gs_device_t *device, const char *shader, const char *file, gs_shader_type shader_type);
};


// Helpers
static inline MTLPixelFormat ConvertGSTextureFormat(gs_color_format format)
{
    switch (format) {
        case GS_UNKNOWN:     return MTLPixelFormatInvalid;
        case GS_A8:          return MTLPixelFormatA8Unorm;
        case GS_R8:          return MTLPixelFormatR8Unorm;
        case GS_RGBA:        return MTLPixelFormatRGBA8Unorm;
        case GS_BGRX:        return MTLPixelFormatBGRA8Unorm;
        case GS_BGRA:        return MTLPixelFormatBGRA8Unorm;
        case GS_R10G10B10A2: return MTLPixelFormatRGB10A2Unorm;
        case GS_RGBA16:      return MTLPixelFormatRGBA16Unorm;
        case GS_R16:         return MTLPixelFormatR16Unorm;
        case GS_RGBA16F:     return MTLPixelFormatRGBA16Float;
        case GS_RGBA32F:     return MTLPixelFormatRGBA32Float;
        case GS_RG16F:       return MTLPixelFormatRG16Float;
        case GS_RG32F:       return MTLPixelFormatRG32Float;
        case GS_R16F:        return MTLPixelFormatR16Float;
        case GS_R32F:        return MTLPixelFormatR32Float;
        case GS_DXT1:        return MTLPixelFormatBC1_RGBA;
        case GS_DXT3:        return MTLPixelFormatBC2_RGBA;
        case GS_DXT5:        return MTLPixelFormatBC3_RGBA;
        case GS_R8G8:        return MTLPixelFormatRG8Unorm;
    }
    return MTLPixelFormatInvalid;
}
