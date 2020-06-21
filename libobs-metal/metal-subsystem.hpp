#pragma once

#include <graphics/graphics.h>
#include <graphics/device-exports.h>
#include <graphics/shader-parser.h>

#include <iostream>
#include <vector>
#include <queue>
#include <mutex>
#include <stack>

#include <util/base.h>
#include <graphics/matrix4.h>
#include <graphics/vec2.h>

#import <AppKit/NSView.h>
#import <QuartzCore/CoreAnimation.h>
#import <Metal/Metal.h>

using namespace std;

static inline MTLPrimitiveType ConvertGSTopology(gs_draw_mode mode)
{
   switch (mode) {
   case GS_POINTS:    return MTLPrimitiveTypePoint;
   case GS_LINES:     return MTLPrimitiveTypeLine;
   case GS_LINESTRIP: return MTLPrimitiveTypeLineStrip;
   case GS_TRIS:      return MTLPrimitiveTypeTriangle;
   case GS_TRISTRIP:  return MTLPrimitiveTypeTriangleStrip;
   }

   return MTLPrimitiveTypePoint;
}

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
    gs_init_data *initData;
    
    NSView *view;
    CAMetalLayer *metalLayer;
    gs_texture *nextTarget;
    id<CAMetalDrawable> nextDrawable;
    uint32_t numBuffers;
    
    gs_texture *CurrentTarget();
    gs_texture *NextTarget();
    
    void Resize(uint32_t cx, uint32_t cy);
    void Rebuild();
    
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


struct gs_shader : gs_object {
    const char *shader;
    const char *file;
    gs_shader_type shaderType;
    
    string metalShader;
    id<MTLLibrary> metalLibrary;
    id<MTLFunction> metalFunction;
    vector<gs_shader_param> params;
    size_t constantSize = 0;
    vector<uint8_t> data;
    
    void UpdateParam(uint8_t *data, gs_shader_param &param);
    void UploadParams(id<MTLRenderCommandEncoder> commandEncoder);
    void BuildConstantBuffer();
    void Compile();
    
    gs_shader(gs_device_t *device, const char *shader, const char *file, gs_shader_type shader_type);
};

struct gs_pixel_shader : gs_shader {
    vector<ShaderSampler*> samplers;
    
    inline void GetPixelShaderSamplerStates(gs_sampler_state **states)
    {
        size_t i;
        for (i = 0; i < samplers.size(); i++)
            states[i] = &samplers[i]->sampler;
        for (; i < GS_MAX_TEXTURES; i++)
            states[i] = nullptr;
    }
    
    gs_pixel_shader(gs_device_t *device, const char *shader, const char *file);
};

struct gs_vertex_shader : gs_shader {
   MTLVertexDescriptor *vertexDescriptor;

   bool hasNormals;
   bool hasColors;
   bool hasTangents;
   uint32_t texUnits;

    gs_shader_param *worldMatrix;
    gs_shader_param *viewProjectionMatrix;

   inline uint32_t NumBuffersExpected() const
   {
       uint32_t count = texUnits + 1;
       if (hasNormals) count++;
       if (hasColors) count++;
       if (hasTangents) count++;

       return count;
   }

   gs_vertex_shader(gs_device_t *device, const char *shader, const char *file);
};

struct gs_texture : gs_object {
    // Data from application
    uint32_t width;
    uint32_t height;
    uint32_t depth;
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
    
    // Init from data
    gs_texture(gs_device_t *device, uint32_t width, uint32_t height, uint32_t depth, gs_color_format color_format, uint32_t levels, const uint8_t **data, uint32_t flags, gs_texture_type texture_type);
    
    // Init from existing MTLTexture
    gs_texture(gs_device_t *device, id<MTLTexture> texture);
};

struct gs_vertex_buffer : gs_object {
    const bool                 isDynamic;
    unique_ptr<gs_vb_data, decltype(&gs_vbdata_destroy)> vbData;
    
    id<MTLBuffer>              vertexBuffer;
    id<MTLBuffer>              normalBuffer;
    id<MTLBuffer>              colorBuffer;
    id<MTLBuffer>              tangentBuffer;
    vector<id<MTLBuffer>> uvBuffers;
    
    inline id<MTLBuffer> PrepareBuffer(void *array, size_t elementSize, string *name);
    void PrepareBuffers();
    
    void MakeBufferList(gs_vertex_shader *shader,
                        std::vector<id<MTLBuffer>> &buffers);
    
    inline id<MTLBuffer> InitBuffer(size_t elementSize, void *array,
                                    const char *name);
    void InitBuffers();
    
    // Mem management
    inline void Release()
     {
         vertexBuffer = nil;
         normalBuffer = nil;
         colorBuffer  = nil;
         tangentBuffer = nil;
         uvBuffers.clear();
     }
    
    gs_vertex_buffer(gs_device_t *device, struct gs_vb_data *data, uint32_t flags);
};

struct gs_index_buffer : gs_object {
    gs_index_type indexType;
    unique_ptr<void, decltype(&bfree)> indices;
    const size_t num;
    const size_t len;
    const bool isDynamic;
    
    id<MTLBuffer>       metalIndexBuffer;
    MTLIndexType        metalIndexType;
    
    void PrepareBuffer();
    void InitBuffer();
    
    gs_index_buffer(gs_device_t *device, gs_index_type type, void *indices, size_t num, uint32_t flags);
};

struct gs_zstencil_buffer : gs_object {
    uint32_t width;
    uint32_t height;
    gs_zstencil_format zStencilFormat;
    
    MTLTextureDescriptor     *textureDescriptor;
    id<MTLTexture>           metalTexture;
    
    void InitBuffer();
    
    gs_zstencil_buffer(gs_device_t *device, uint32_t width, uint32_t height, gs_zstencil_format format);
};

struct gs_stage_surface : gs_object {
    uint32_t width;
    uint32_t height;
    gs_color_format colorFormat;
    
    MTLTextureDescriptor  *textureDescriptor;
    id<MTLTexture>        metalTexture;
    vector<uint8_t>       textureData;
    
    void DownloadTexture();
    void InitTexture();
    
    gs_stage_surface(gs_device_t *device, uint32_t width, uint32_t height, gs_color_format color_format);
};

struct ShaderError {
   const string error;

   inline ShaderError(NSError *error)
       : error ([[error localizedDescription] UTF8String])
   {
   }
};

struct ClearState {
   uint32_t    flags;
   struct vec4 color;
   float       depth;
   uint8_t     stencil;

   inline ClearState()
       : flags   (0),
         color   ({}),
         depth   (0.0f),
         stencil (0)
   {
   }
};

struct BlendState {
   bool          blendEnabled;
   gs_blend_type srcFactorC;
   gs_blend_type destFactorC;
   gs_blend_type srcFactorA;
   gs_blend_type destFactorA;

   bool          redEnabled;
   bool          greenEnabled;
   bool          blueEnabled;
   bool          alphaEnabled;

   inline BlendState()
       : blendEnabled (true),
         srcFactorC   (GS_BLEND_SRCALPHA),
         destFactorC  (GS_BLEND_INVSRCALPHA),
         srcFactorA   (GS_BLEND_ONE),
         destFactorA  (GS_BLEND_ONE),
         redEnabled   (true),
         greenEnabled (true),
         blueEnabled  (true),
         alphaEnabled (true)
   {
   }

   inline BlendState(const BlendState &state)
   {
       memcpy(this, &state, sizeof(BlendState));
   }
};

 struct RasterState {
   gs_rect        viewport;
   gs_cull_mode   cullMode;
   bool           scissorEnabled;
   gs_rect        scissorRect;

   MTLViewport    mtlViewport;
   MTLCullMode    mtlCullMode;
   MTLScissorRect mtlScissorRect;

   inline RasterState()
       : viewport       (),
         cullMode       (GS_BACK),
         scissorEnabled (false),
         scissorRect    (),
         mtlCullMode    (MTLCullModeBack)
   {
   }

   inline RasterState(const RasterState &state)
   {
       memcpy(this, &state, sizeof(RasterState));
   }
};

 struct StencilSide {
   gs_depth_test test;
   gs_stencil_op_type fail;
   gs_stencil_op_type zfail;
   gs_stencil_op_type zpass;

   inline StencilSide()
       : test  (GS_ALWAYS),
         fail  (GS_KEEP),
         zfail (GS_KEEP),
         zpass (GS_KEEP)
   {
   }
};

 struct ZStencilState {
   bool          depthEnabled;
   bool          depthWriteEnabled;
   gs_depth_test depthFunc;

   bool          stencilEnabled;
   bool          stencilWriteEnabled;
   StencilSide   stencilFront;
   StencilSide   stencilBack;

   MTLDepthStencilDescriptor *dsd;

   inline ZStencilState()
       : depthEnabled        (true),
         depthWriteEnabled   (true),
         depthFunc           (GS_LESS),
         stencilEnabled      (false),
         stencilWriteEnabled (true)
   {
       dsd = [[MTLDepthStencilDescriptor alloc] init];
   }

   inline ZStencilState(const ZStencilState &state)
   {
       memcpy(this, &state, sizeof(ZStencilState));
   }
};

struct gs_device {
    id<MTLDevice> metalDevice;
    id<MTLRenderPipelineState> renderPipelineState;
    id<MTLDepthStencilState> depthStencilState;
    id<MTLCommandQueue> commandQueue;
    id<MTLCommandBuffer> commandBuffer;
    
    uint32_t deviceIndex;
    gs_swap_chain *currentSwapChain;
    gs_vertex_buffer *currentVertexBuffer;
    gs_index_buffer *currentIndexBuffer;
    gs_texture *currentTextures[GS_MAX_TEXTURES];
    gs_sampler_state *currentSamplers[GS_MAX_TEXTURES];
    gs_vertex_shader *currentVertexShader;
    gs_pixel_shader *currentPixelShader;
    gs_texture *preserveClearTarget;
    
    // Might be movable to swapchain?
    MTLRenderPassDescriptor *renderPassDescriptor;
    MTLRenderPipelineDescriptor *renderPipelineDescriptor;
    gs_texture *currentRenderTarget;
    int currentRenderSide;
    gs_zstencil_buffer *currentZStencilBuffer;
    bool pipelineStateChanged;
    
    gs_vertex_buffer *lastVertexBuffer = nil;
    gs_vertex_shader *lastVertexShader = nil;
    
    stack<pair<gs_texture *, ClearState>> clearStates;
    BlendState                  blendState;
    RasterState                 rasterState;
    ZStencilState               zstencilState;
    
    mutex mutexObj;
    vector<id<MTLBuffer>> curBufferPool;
    queue<vector<id<MTLBuffer>>> bufferPools;
    vector<id<MTLBuffer>>  unusedBufferPool;
    
    matrix4 currentProjectionMatrix;
     matrix4 currentViewMatrix;
     matrix4 currentViewProjectionMatrix;
    
    /* Create Draw Command */
    void SetClear();
    void LoadSamplers(id<MTLRenderCommandEncoder> commandEncoder);
    void LoadRasterState(id<MTLRenderCommandEncoder> commandEncoder);
    void LoadZStencilState(id<MTLRenderCommandEncoder> commandEncoder);
    void UpdateViewProjMatrix();
    void UploadVertexBuffer(id<MTLRenderCommandEncoder> commandEncoder);
    void UploadTextures(id<MTLRenderCommandEncoder> commandEncoder);
    void UploadSamplers(id<MTLRenderCommandEncoder> commandEncoder);
    void DrawPrimitives(id<MTLRenderCommandEncoder> commandEncoder, gs_draw_mode drawMode, uint32_t startVert, uint32_t numVerts);
    void Draw(gs_draw_mode drawMode, uint32_t startVert, uint32_t numVerts);
    
    id<MTLBuffer> CreateBuffer(void *data, size_t length);
    id<MTLBuffer> GetBuffer(void *data, size_t length);
    void PushResources();
    void ReleaseResources();
    
    void CopyTex(id<MTLTexture> dst, uint32_t dst_x, uint32_t dst_y, gs_texture_t *src, uint32_t src_x, uint32_t src_y, uint32_t src_w, uint32_t src_h);
    
    gs_device(uint32_t adapterIdx);
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
