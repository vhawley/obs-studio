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
    
    gs_object *nextObject;
    gs_object *previousObject;
    
    gs_object(gs_device_t *device, gs_object_type type);
    ~gs_object();
};

struct gs_swap_chain : gs_object {
    gs_init_data *initData = nil;
    
    NSView *view = nil;
    CAMetalLayer *metalLayer = nil;
    gs_texture *nextTarget = nil;
    id<CAMetalDrawable> nextDrawable;
    uint32_t numBuffers;
    
    gs_texture *CurrentTarget();
    gs_texture *NextTarget();
    
    void Resize(uint32_t cx, uint32_t cy);
    
    inline void Release()
     {
         nextTarget = nil;
         nextDrawable = nil;
     }
     void Rebuild();
    
    gs_swap_chain(gs_device *device, const gs_init_data *data);
};

struct gs_sampler_state : gs_object {
    const gs_sampler_info info;
    
    MTLSamplerDescriptor  *samplerDescriptor = nil;
    id<MTLSamplerState>   samplerState;
    
    void InitSampler();
    
    inline void Release() {
        samplerState = nil;
    }
    inline void Rebuild() {
        InitSampler();
    }
    
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
    
    struct gs_sampler_state    *nextSampler = nil;
    
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
    
    void Release()
    {
        metalFunction = nil;
        metalLibrary = nil;
    }
    void Rebuild();
    
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
            states[i] = nil;
    }
    
    gs_pixel_shader(gs_device_t *device, const char *shader, const char *file);
};

struct gs_vertex_shader : gs_shader {
    MTLVertexDescriptor *vertexDescriptor;
    
    bool hasNormals;
    bool hasColors;
    bool hasTangents;
    uint32_t texUnits;
    
    gs_shader_param *worldMatrix = nil;
    gs_shader_param *viewProjectionMatrix = nil;
    
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
    MTLTextureDescriptor *metalTextureDescriptor = nil;
    MTLPixelFormat metalPixelFormat;
    
    void GenerateMipmap();
    void BackupTexture(const uint8_t **data);
    void UploadTexture();
    
    void InitTextureDescriptor();
    void RebuildTextureDescriptor();
    
    void InitTexture();
    
    inline void Release() {
        metalTexture = nil;
    }
    void Rebuild();
    
    // Init from data
    gs_texture(gs_device_t *device, uint32_t width, uint32_t height, uint32_t depth, gs_color_format color_format, uint32_t levels, const uint8_t **data, uint32_t flags, gs_texture_type texture_type);
    
    // Init from existing MTLTexture
    gs_texture(gs_device_t *device, id<MTLTexture> texture);
};

struct gs_vertex_buffer : gs_object {
    const bool                 isDynamic;
    gs_vb_data *vbData;
    
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
    void Rebuild();
    
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
    
    inline void Release() {
        metalIndexBuffer = nil;
    }
    void Rebuild();
    
    gs_index_buffer(gs_device_t *device, gs_index_type type, void *indices, size_t num, uint32_t flags);
};

struct gs_zstencil_buffer : gs_object {
    uint32_t width;
    uint32_t height;
    gs_zstencil_format zStencilFormat;
    
    MTLTextureDescriptor     *textureDescriptor = nil;
    id<MTLTexture>           metalTexture;
    
    void InitBuffer();
    
    inline void Release() {
        metalTexture = nil;
    }
    inline void Rebuild() {
        InitBuffer();
    }
    
    gs_zstencil_buffer(gs_device_t *device, uint32_t width, uint32_t height, gs_zstencil_format format);
};

struct gs_stage_surface : gs_object {
    uint32_t width;
    uint32_t height;
    gs_color_format colorFormat;
    
    MTLTextureDescriptor  *textureDescriptor = nil;
    id<MTLTexture>        metalTexture;
    vector<uint8_t>       textureData;
    
    void DownloadTexture();
    void InitTexture();
    
    inline void Release() {
        metalTexture = nil;
    }
    inline void Rebuild() {
        InitTexture();
    }
    
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
    gs_swap_chain *currentSwapChain = nil;
    gs_vertex_buffer *currentVertexBuffer  = nil;
    gs_index_buffer *currentIndexBuffer  = nil;
    gs_texture *currentTextures[GS_MAX_TEXTURES];
    gs_sampler_state *currentSamplers[GS_MAX_TEXTURES];
    gs_vertex_shader *currentVertexShader  = nil;
    gs_pixel_shader *currentPixelShader  = nil;
    gs_texture *preserveClearTarget = nil;
    gs_stage_surface *currentStageSurface  = nil;
    
    // Might be movable to swapchain?
    MTLRenderPassDescriptor *renderPassDescriptor = nil;
    MTLRenderPipelineDescriptor *renderPipelineDescriptor = nil;
    gs_texture *currentRenderTarget = nil;
    int currentRenderSide = 0;
    gs_zstencil_buffer *currentZStencilBuffer = nil;
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
    stack<matrix4> projectionStack;
    
    gs_object *firstObject = nil;
    
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
    void RebuildDevice();
    void InitDevice(uint32_t index);
    
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

static inline MTLCullMode ConvertGSCullMode(gs_cull_mode mode)
{
    switch (mode) {
        case GS_BACK:    return MTLCullModeBack;
        case GS_FRONT:   return MTLCullModeFront;
        case GS_NEITHER: return MTLCullModeNone;
    }
    
    return MTLCullModeBack;
}

static inline MTLBlendFactor ConvertGSBlendType(gs_blend_type type)
{
    switch (type) {
        case GS_BLEND_ZERO:
            return MTLBlendFactorZero;
        case GS_BLEND_ONE:
            return MTLBlendFactorOne;
        case GS_BLEND_SRCCOLOR:
            return MTLBlendFactorSourceColor;
        case GS_BLEND_INVSRCCOLOR:
            return MTLBlendFactorOneMinusSourceColor;
        case GS_BLEND_SRCALPHA:
            return MTLBlendFactorSourceAlpha;
        case GS_BLEND_INVSRCALPHA:
            return MTLBlendFactorOneMinusSourceAlpha;
        case GS_BLEND_DSTCOLOR:
            return MTLBlendFactorDestinationColor;
        case GS_BLEND_INVDSTCOLOR:
            return MTLBlendFactorOneMinusDestinationColor;
        case GS_BLEND_DSTALPHA:
            return MTLBlendFactorDestinationAlpha;
        case GS_BLEND_INVDSTALPHA:
            return MTLBlendFactorOneMinusDestinationAlpha;
        case GS_BLEND_SRCALPHASAT:
            return MTLBlendFactorSourceAlphaSaturated;
    }
    
    return MTLBlendFactorOne;
}

static inline MTLCompareFunction ConvertGSDepthTest(gs_depth_test test)
{
    switch (test) {
        case GS_NEVER:    return MTLCompareFunctionNever;
        case GS_LESS:     return MTLCompareFunctionLess;
        case GS_LEQUAL:   return MTLCompareFunctionLessEqual;
        case GS_EQUAL:    return MTLCompareFunctionEqual;
        case GS_GEQUAL:   return MTLCompareFunctionGreaterEqual;
        case GS_GREATER:  return MTLCompareFunctionGreater;
        case GS_NOTEQUAL: return MTLCompareFunctionNotEqual;
        case GS_ALWAYS:   return MTLCompareFunctionAlways;
    }
    
    return MTLCompareFunctionNever;
}

static inline MTLStencilOperation ConvertGSStencilOp(gs_stencil_op_type op)
{
    switch (op) {
        case GS_KEEP:    return MTLStencilOperationKeep;
        case GS_ZERO:    return MTLStencilOperationZero;
        case GS_REPLACE: return MTLStencilOperationReplace;
        case GS_INCR:    return MTLStencilOperationIncrementWrap;
        case GS_DECR:    return MTLStencilOperationDecrementWrap;
        case GS_INVERT:  return MTLStencilOperationInvert;
    }
    
    return MTLStencilOperationKeep;
}

static inline MTLViewport ConvertGSRectToMTLViewport(gs_rect rect)
{
    MTLViewport ret;
    ret.originX = rect.x;
    ret.originY = rect.y;
    ret.width   = rect.cx;
    ret.height  = rect.cy;
    ret.znear   = 0.0;
    ret.zfar    = 1.0;
    return ret;
}

static inline MTLScissorRect ConvertGSRectToMTLScissorRect(gs_rect rect)
{
   MTLScissorRect ret;
   ret.x      = rect.x;
   ret.y      = rect.y;
   ret.width  = rect.cx;
   ret.height = rect.cy;
   return ret;
}

static inline MTLSamplerAddressMode ConvertGSAddressMode(gs_address_mode mode)
{
   switch (mode) {
   case GS_ADDRESS_WRAP:
       return MTLSamplerAddressModeRepeat;
   case GS_ADDRESS_CLAMP:
       return MTLSamplerAddressModeClampToEdge;
   case GS_ADDRESS_MIRROR:
       return MTLSamplerAddressModeMirrorRepeat;
   case GS_ADDRESS_BORDER:
       return MTLSamplerAddressModeClampToBorderColor;
   case GS_ADDRESS_MIRRORONCE:
       return MTLSamplerAddressModeMirrorClampToEdge;
   }

   return MTLSamplerAddressModeRepeat;
}

 static inline MTLSamplerMinMagFilter ConvertGSMinFilter(gs_sample_filter filter)
{
   switch (filter) {
   case GS_FILTER_POINT:
       return MTLSamplerMinMagFilterNearest;
   case GS_FILTER_LINEAR:
       return MTLSamplerMinMagFilterLinear;
   case GS_FILTER_MIN_MAG_POINT_MIP_LINEAR:
       return MTLSamplerMinMagFilterNearest;
   case GS_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT:
       return MTLSamplerMinMagFilterNearest;
   case GS_FILTER_MIN_POINT_MAG_MIP_LINEAR:
       return MTLSamplerMinMagFilterNearest;
   case GS_FILTER_MIN_LINEAR_MAG_MIP_POINT:
       return MTLSamplerMinMagFilterLinear;
   case GS_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
       return MTLSamplerMinMagFilterLinear;
   case GS_FILTER_MIN_MAG_LINEAR_MIP_POINT:
       return MTLSamplerMinMagFilterLinear;
   case GS_FILTER_ANISOTROPIC:
       return MTLSamplerMinMagFilterLinear;
   }

   return MTLSamplerMinMagFilterNearest;
}

 static inline MTLSamplerMinMagFilter ConvertGSMagFilter(gs_sample_filter filter)
{
   switch (filter) {
   case GS_FILTER_POINT:
       return MTLSamplerMinMagFilterNearest;
   case GS_FILTER_LINEAR:
       return MTLSamplerMinMagFilterLinear;
   case GS_FILTER_MIN_MAG_POINT_MIP_LINEAR:
       return MTLSamplerMinMagFilterNearest;
   case GS_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT:
       return MTLSamplerMinMagFilterLinear;
   case GS_FILTER_MIN_POINT_MAG_MIP_LINEAR:
       return MTLSamplerMinMagFilterLinear;
   case GS_FILTER_MIN_LINEAR_MAG_MIP_POINT:
       return MTLSamplerMinMagFilterNearest;
   case GS_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
       return MTLSamplerMinMagFilterNearest;
   case GS_FILTER_MIN_MAG_LINEAR_MIP_POINT:
       return MTLSamplerMinMagFilterLinear;
   case GS_FILTER_ANISOTROPIC:
       return MTLSamplerMinMagFilterLinear;
   }

   return MTLSamplerMinMagFilterNearest;
}

 static inline MTLSamplerMipFilter ConvertGSMipFilter(gs_sample_filter filter)
{
   switch (filter) {
   case GS_FILTER_POINT:
       return MTLSamplerMipFilterNearest;
   case GS_FILTER_LINEAR:
       return MTLSamplerMipFilterLinear;
   case GS_FILTER_MIN_MAG_POINT_MIP_LINEAR:
       return MTLSamplerMipFilterLinear;
   case GS_FILTER_MIN_POINT_MAG_LINEAR_MIP_POINT:
       return MTLSamplerMipFilterNearest;
   case GS_FILTER_MIN_POINT_MAG_MIP_LINEAR:
       return MTLSamplerMipFilterLinear;
   case GS_FILTER_MIN_LINEAR_MAG_MIP_POINT:
       return MTLSamplerMipFilterNearest;
   case GS_FILTER_MIN_LINEAR_MAG_POINT_MIP_LINEAR:
       return MTLSamplerMipFilterLinear;
   case GS_FILTER_MIN_MAG_LINEAR_MIP_POINT:
       return MTLSamplerMipFilterNearest;
   case GS_FILTER_ANISOTROPIC:
       return MTLSamplerMipFilterLinear;
   }

   return MTLSamplerMipFilterNearest;
}
