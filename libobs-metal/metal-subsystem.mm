#include "metal-subsystem.hpp"

gs_device::gs_device(uint32_t adapter)
: currentRenderSide(0),
pipelineStateChanged(false)
{
    NSArray *metalDevices = MTLCopyAllDevices();
    
    deviceIndex = adapter;
    
    NSUInteger numDevices = [metalDevices count];
    if (!metalDevices || numDevices < 1 || adapter > numDevices - 1) {
        throw "Failed to get Metal devices";
    }
    
    metalDevice = [metalDevices objectAtIndex:deviceIndex];
    renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
    renderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    commandQueue = [metalDevice newCommandQueue];
    [metalDevices dealloc];
}

const char *device_get_name(void) {
    return "Metal";
}

int device_get_type(void) {
    return GS_DEVICE_METAL;
}

const char *device_preprocessor_name(void)
{
    return "_METAL";
}


int device_create(gs_device_t **p_device, uint32_t adapter)
{
    gs_device *device = NULL;
    blog(LOG_INFO, "---------------------------------");
    blog(LOG_INFO, "Initializing Metal...");
    
    device = new gs_device(adapter);
    blog(LOG_INFO, "device_create (Metal): Found adapter %s", [device->metalDevice.name UTF8String]);
    
    *p_device = device;
    return GS_SUCCESS;
}

void device_destroy(gs_device_t *device)
{
    delete device;
}

void device_enter_context(gs_device_t *device)
{
    UNUSED_PARAMETER(device);
}

void device_leave_context(gs_device_t *device)
{
    UNUSED_PARAMETER(device);
}

void *device_get_device_obj(gs_device_t *device)
{
    assert(device != NULL);
    return device->metalDevice;
}

bool device_enum_adapters(
                          bool (*callback)(void *param, const char *name, uint32_t id),
                          void *param)
{
    uint32_t i = 0;
    NSArray *devices = MTLCopyAllDevices();
    if (devices == nil)
        return false;
    
    for (id<MTLDevice> device in devices) {
        if (!callback(param, [[device name] UTF8String], i++))
            break;
    }
    
    [devices dealloc];
    return true;
}

gs_swapchain_t *device_swapchain_create(gs_device_t *device,
                                        const struct gs_init_data *data)
{
    gs_swap_chain *swap_chain;
    try {
        swap_chain = new gs_swap_chain(device, data);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_swapchain_create (Metal): %s", error);
    }
    
    return swap_chain;
}

void device_resize(gs_device_t *device, uint32_t x, uint32_t y)
{
    if (device->currentSwapChain == nil) {
        blog(LOG_WARNING, "device_resize (Metal): No active swap");
        return;
    }
    
    try {
        id<MTLTexture> renderTarget = nil;
        id<MTLTexture> zstencilTarget = nil;
        
        device->renderPassDescriptor.colorAttachments[0].texture = nil;
        device->renderPassDescriptor.depthAttachment.texture     = nil;
        device->renderPassDescriptor.stencilAttachment.texture   = nil;
        device->currentSwapChain->Resize(x, y);
        
        if (device->currentRenderTarget)
            renderTarget = device->currentRenderTarget->metalTexture;
        if (device->currentZStencilBuffer)
            zstencilTarget  = device->currentZStencilBuffer->metalTexture;
        
        device->renderPassDescriptor.colorAttachments[0].texture = renderTarget;
        device->renderPassDescriptor.depthAttachment.texture     = zstencilTarget;
        device->renderPassDescriptor.stencilAttachment.texture   = zstencilTarget;
        
    } catch (const char *error) {
        blog(LOG_ERROR, "device_resize (Metal): %s", error);
    }
}

void device_get_size(const gs_device_t *device, uint32_t *x,
                     uint32_t *y)
{
    if (device->currentSwapChain) {
        CGSize size = device->currentSwapChain->metalLayer.drawableSize;
        *x = size.width;
        *y = size.height;
    } else {
        blog(LOG_WARNING, "device_get_size (Metal): No swap chain");
        *x = 0;
        *y = 0;
    }
}

uint32_t device_get_width(const gs_device_t *device)
{
    if (device->currentSwapChain) {
        CGSize size = device->currentSwapChain->metalLayer.drawableSize;
        return size.width;
    } else {
        blog(LOG_WARNING, "device_get_width (Metal): No swap chain");
        return 0;
    }
}

uint32_t device_get_height(const gs_device_t *device)
{
    if (device->currentSwapChain) {
        CGSize size = device->currentSwapChain->metalLayer.drawableSize;
        return size.height;
    } else {
        blog(LOG_WARNING, "device_get_height (Metal): No swap chain");
        return 0;
    }
}

gs_texture_t *device_texture_create(gs_device_t *device, uint32_t width, uint32_t height,
                                    enum gs_color_format color_format, uint32_t levels,
                                    const uint8_t **data, uint32_t flags)
{
    gs_texture *texture;
    
    try {
        texture = new gs_texture(device, width, height, 0, color_format, levels, data, flags, GS_TEXTURE_2D);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_texture_create (Metal): %s", error);
    }
    
    return texture;
}

gs_texture_t *device_cubetexture_create(gs_device_t *device, uint32_t size,
                                        enum gs_color_format color_format, uint32_t levels,
                                        const uint8_t **data, uint32_t flags)
{
    gs_texture *texture;
    
    try {
        texture = new gs_texture(device, size, size, 0, color_format, levels, data, flags, GS_TEXTURE_CUBE);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_cubetexture_create (Metal): %s", error);
    }
    
    return texture;
}

gs_texture_t *device_voltexture_create(gs_device_t *device, uint32_t width, uint32_t height,
                                       uint32_t depth, enum gs_color_format color_format,
                                       uint32_t levels, const uint8_t *const *data,
                                       uint32_t flags)
{
    gs_texture *texture;
    
    try {
        texture = new gs_texture(device, width, height, depth, color_format, levels, (const uint8_t **)data, flags, GS_TEXTURE_3D);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_voltexture_create (Metal): %s", error);
    }
    
    return texture;
}

gs_zstencil_t *device_zstencil_create(gs_device_t *device,
                                      uint32_t width, uint32_t height, enum gs_zstencil_format format)
{
    gs_zstencil_buffer *buffer;
    try {
        buffer = new gs_zstencil_buffer(device, width, height, format);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_zstencil_create (Metal): %s", error);
    }
    
    return buffer;
}

gs_stagesurf_t *
device_stagesurface_create(gs_device_t *device, uint32_t width, uint32_t height, enum gs_color_format color_format)
{
    gs_stage_surface *stagesurf;
    
    try {
        stagesurf = new gs_stage_surface(device, width, height, color_format);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_stagesurface_create (Metal): %s", error);
    }
    
    return stagesurf;
}

gs_samplerstate_t *
device_samplerstate_create(gs_device_t *device, const struct gs_sampler_info *info)
{
    gs_sampler_state *sampler_state;
    
    try {
        sampler_state = new gs_sampler_state(device, info);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_samplerstate_create (Metal): %s", error);
    }
    
    return sampler_state;
}

gs_shader_t *device_vertexshader_create(gs_device_t *device,
                                        const char *shader,
                                        const char *file,
                                        char **error_string)
{
    gs_vertex_shader *vertex_shader;
    
    try {
        vertex_shader = new gs_vertex_shader(device, shader, file);
    } catch (char *error) {
        blog(LOG_ERROR, "device_vertexshader_create (Metal): %s", error);
        *error_string = error;
    }
    
    return vertex_shader;
}

gs_shader_t *device_pixelshader_create(gs_device_t *device,
                                       const char *shader,
                                       const char *file,
                                       char **error_string)
{
    gs_pixel_shader *pixel_shader;
    
    try {
        pixel_shader = new gs_pixel_shader(device, shader, file);
    } catch (char *error) {
        blog(LOG_ERROR, "device_pixelshader_create (Metal): %s", error);
        *error_string = error;
    }
    
    return pixel_shader;
}

gs_vertbuffer_t *device_vertexbuffer_create(gs_device_t *device, struct gs_vb_data *data, uint32_t flags)
{
    gs_vertex_buffer *buffer;
    try {
        buffer = new gs_vertex_buffer(device, data, flags);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_vertexbuffer_create (Metal): %s", error);
    }
    
    return buffer;
}

gs_indexbuffer_t *device_indexbuffer_create(gs_device_t *device,
                                            enum gs_index_type type,
                                            void *indices, size_t num,
                                            uint32_t flags)
{
    gs_index_buffer *buffer;
    try {
        buffer = new gs_index_buffer(device, type, indices, num, flags);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_indexbuffer_create (Metal): %s",
             error);
    }
    
    return buffer;
}

gs_timer_t *device_timer_create(gs_device_t *device)
{
    UNUSED_PARAMETER(device);
    return NULL;
}

gs_timer_range_t *device_timer_range_create(gs_device_t *device)
{
    UNUSED_PARAMETER(device);
    return NULL;
}

enum gs_texture_type device_get_texture_type(const gs_texture_t *texture)
{
    assert(texture->objectType == GS_TEXTURE);
    return texture->textureType;
}

void device_load_vertexbuffer(gs_device_t *device,
                              gs_vertbuffer_t *vertbuffer)
{
    assert(device != NULL);
    if (device->currentVertexBuffer != vertbuffer)
        device->currentVertexBuffer = vertbuffer;
}

void device_load_indexbuffer(gs_device_t *device,
                             gs_indexbuffer_t *indexbuffer)
{
    assert(device != NULL);
    if (device->currentIndexBuffer != indexbuffer)
        device->currentIndexBuffer = indexbuffer;
}

void device_load_texture(gs_device_t *device, gs_texture_t *tex,
                         int unit)
{
    assert(device != NULL);
    assert(unit >= 0);
    assert(unit < GS_MAX_TEXTURES);
    if (device->currentTextures[unit] != tex)
        device->currentTextures[unit] = tex;
}

void device_load_samplerstate(gs_device_t *device,
                              gs_samplerstate_t *samplerstate, int unit)
{
    assert(device != nil);
    assert(unit >= 0);
    assert(unit < GS_MAX_TEXTURES);
    if (device->currentSamplers[unit] != samplerstate)
        device->currentSamplers[unit] = samplerstate;
}

void device_load_vertexshader(gs_device_t *device,
                              gs_shader_t *vertshader)
{
    id<MTLFunction>     function  = nil;
    MTLVertexDescriptor *vertDesc = nil;
    
    if (device->currentVertexShader == vertshader)
        return;
    
    gs_vertex_shader *vs = static_cast<gs_vertex_shader*>(vertshader);
    if (vertshader) {
        if (vertshader->shaderType != GS_SHADER_VERTEX) {
            blog(LOG_ERROR, "device_load_vertexshader (Metal): "
                 "Specified shader is not a vertex "
                 "shader");
            return;
        }
        
        function = vs->metalFunction;
        vertDesc = vs->vertexDescriptor;
    }
    
    device->currentVertexShader = vs;
    
    device->renderPipelineDescriptor.vertexFunction = function;
    device->renderPipelineDescriptor.vertexDescriptor = vertDesc;
    
    device->pipelineStateChanged = true;
}

void device_load_pixelshader(gs_device_t *device,
                             gs_shader_t *pixelshader)
{
    assert(device != nil);
    
    gs_pixel_shader *ps = (gs_pixel_shader *)pixelshader;
    
    if (device->currentPixelShader == ps)
        return;
    
    id<MTLFunction> function = nil;
    gs_sampler_state *states[GS_MAX_TEXTURES];
    
    if (pixelshader) {
        function = ps->metalFunction;
        ps->GetPixelShaderSamplerStates(states);
    }
    
    // Clear textures. may not be needed?
    memset(device->currentTextures, 0, sizeof(device->currentTextures));
    
    device->currentPixelShader = ps;
    for (size_t i = 0; i < GS_MAX_TEXTURES; i++)
        device->currentSamplers[i] = states[i];
    
    [device->renderPipelineDescriptor setFragmentFunction:function];
    
    device->pipelineStateChanged = true;
}

void device_load_default_samplerstate(gs_device_t *device, bool b_3d, int unit)
{
    /* TODO */
    UNUSED_PARAMETER(device);
    UNUSED_PARAMETER(b_3d);
    UNUSED_PARAMETER(unit);
}

gs_shader_t *device_get_vertex_shader(const gs_device_t *device)
{
    return device->currentVertexShader;
}

gs_shader_t *device_get_pixel_shader(const gs_device_t *device)
{
    return device->currentPixelShader;
}

gs_texture_t *device_get_render_target(const gs_device_t *device)
{
    if (device->currentSwapChain &&
        device->currentRenderTarget == device->currentSwapChain->CurrentTarget())
        return nil;
    
    return device->currentRenderTarget;
}

gs_zstencil_t *device_get_zstencil_target(const gs_device_t *device)
{
    return device->currentZStencilBuffer;
}

void device_set_render_target(gs_device_t *device, gs_texture_t *tex,
                              gs_zstencil_t *zstencil)
{
    if (device->currentSwapChain) {
        if (!tex)
            tex = device->currentSwapChain->CurrentTarget();
    }
    
    if (device->currentRenderTarget == tex &&
        device->currentZStencilBuffer == zstencil)
        return;
    
    if (tex && tex->metalTexture == nil) {
        blog(LOG_ERROR, "device_set_render_target (Metal): "
             "texture is null");
        return;
    }
    
    device->currentRenderTarget = tex;
    device->currentRenderSide = 0;
    device->currentZStencilBuffer = zstencil;
    device->renderPassDescriptor.colorAttachments[0].texture = nil;
    device->renderPassDescriptor.depthAttachment.texture   = nil;
    device->renderPassDescriptor.stencilAttachment.texture = nil;
    
    if (tex) {
        device->renderPassDescriptor.colorAttachments[0].texture = tex->metalTexture;
        device->renderPipelineDescriptor.colorAttachments[0].pixelFormat = tex->metalPixelFormat;
    }
    
    if (zstencil) {
        device->renderPassDescriptor.depthAttachment.texture = zstencil->metalTexture;
        device->renderPassDescriptor.stencilAttachment.texture = zstencil->metalTexture;
        device->renderPipelineDescriptor.depthAttachmentPixelFormat = zstencil->textureDescriptor.pixelFormat;
        device->renderPipelineDescriptor.stencilAttachmentPixelFormat = zstencil->textureDescriptor.pixelFormat;
    }
    
    device->pipelineStateChanged = true;
}

void device_set_cube_render_target(gs_device_t *device,
                                   gs_texture_t *cubetex, int side,
                                   gs_zstencil_t *zstencil)
{
    if (device->currentSwapChain) {
        if (!cubetex)
            cubetex = device->currentSwapChain->CurrentTarget();
    }
    
    if (device->currentRenderTarget == cubetex &&
        device->currentRenderSide == side &&
        device->currentZStencilBuffer == zstencil)
        return;
    
    if (cubetex->textureType != GS_TEXTURE_CUBE) {
        blog(LOG_ERROR, "device_set_cube_render_target (Metal): "
             "texture is not a cube texture");
        return;
    }
    
    if (cubetex && cubetex->metalTexture == nil) {
        blog(LOG_ERROR, "device_set_cube_render_target (Metal): "
             "texture is null");
        return;
    }
    
    device->currentRenderTarget = cubetex;
    device->currentRenderSide = side;
    device->currentZStencilBuffer = zstencil;
    device->renderPassDescriptor.colorAttachments[0].texture = nil;
    device->renderPassDescriptor.depthAttachment.texture   = nil;
    device->renderPassDescriptor.stencilAttachment.texture = nil;
    
    if (cubetex) {
        device->renderPassDescriptor.colorAttachments[0].texture = cubetex->metalTexture;
        device->renderPipelineDescriptor.colorAttachments[0].pixelFormat = cubetex->metalPixelFormat;
    }
    
    if (zstencil) {
        device->renderPassDescriptor.depthAttachment.texture = zstencil->metalTexture;
        device->renderPassDescriptor.stencilAttachment.texture = zstencil->metalTexture;
        device->renderPipelineDescriptor.depthAttachmentPixelFormat = zstencil->textureDescriptor.pixelFormat;
        device->renderPipelineDescriptor.stencilAttachmentPixelFormat = zstencil->textureDescriptor.pixelFormat;
    }
    
    device->pipelineStateChanged = true;
}

inline void gs_device::CopyTex(id<MTLTexture> dst,
                               uint32_t dst_x, uint32_t dst_y,
                               gs_texture_t *src, uint32_t src_x, uint32_t src_y,
                               uint32_t src_w, uint32_t src_h)
{
    assert(commandBuffer != nil);
    
    if (src_w == 0)
        src_w = src->width;
    if (src_h == 0)
        src_h = src->height;
    
    @autoreleasepool {
        id<MTLBlitCommandEncoder> commandEncoder =
        [commandBuffer blitCommandEncoder];
        MTLOrigin sourceOrigin      = MTLOriginMake(src_x, src_y, 0);
        MTLSize   sourceSize        = MTLSizeMake(src_w, src_h, 1);
        MTLOrigin destinationOrigin = MTLOriginMake(dst_x, dst_y, 0);
        [commandEncoder copyFromTexture:src->metalTexture
                            sourceSlice:0
                            sourceLevel:0
                           sourceOrigin:sourceOrigin
                             sourceSize:sourceSize
                              toTexture:dst
                       destinationSlice:0
                       destinationLevel:0
                      destinationOrigin:destinationOrigin];
        [commandEncoder endEncoding];
    }
}



void device_copy_texture_region(gs_device_t *device, gs_texture_t *dst,
                                uint32_t dst_x, uint32_t dst_y,
                                gs_texture_t *src, uint32_t src_x,
                                uint32_t src_y, uint32_t src_w,
                                uint32_t src_h)
{
    try {
        
        if (!src)
            throw "Source texture is null";
        if (!dst)
            throw "Destination texture is null";
        if (src->textureType != GS_TEXTURE_2D || dst->textureType != GS_TEXTURE_2D)
            throw "Source and destination textures must be a 2D "
            "textures";
        if (dst->colorFormat != src->colorFormat)
            throw "Source and destination formats do not match";
        
        uint32_t copyWidth  = src_w ? src_w : (src->width - src_x);
        uint32_t copyHeight = src_h ? src_h : (src->height - src_y);
        
        uint32_t dstWidth  = dst->width  - dst_x;
        uint32_t dstHeight = dst->height - dst_y;
        
        if (dstWidth < copyWidth || dstHeight < copyHeight)
            throw "Destination texture region is not big "
            "enough to hold the source region";
        
        if (dst_x == 0 && dst_y == 0 &&
            src_x == 0 && src_y == 0 &&
            src_w == 0 && src_h == 0) {
            copyWidth  = 0;
            copyHeight = 0;
        }
        
        device->CopyTex(dst->metalTexture, dst_x, dst_y,
                        src, src_x, src_y, copyWidth, copyHeight);
        
    } catch(const char *error) {
        blog(LOG_ERROR, "device_copy_texture (Metal): %s", error);
    }
}


void device_copy_texture(gs_device_t *device, gs_texture_t *dst,
                         gs_texture_t *src)
{
    device_copy_texture_region(device, dst, 0, 0, src, 0, 0, 0, 0);
}

void device_stage_texture(gs_device_t *device, gs_stagesurf_t *dst,
                          gs_texture_t *src)
{
    try {
        if (!src)
            throw "Source texture is null";
        if (src->textureType != GS_TEXTURE_2D)
            throw "Source texture must be a 2D texture";
        if (!dst)
            throw "Destination surface is null";
        if (dst->colorFormat != src->colorFormat)
            throw "Source and destination formats do not match";
        if (dst->width  != src->width ||
            dst->height != src->height)
            throw "Source and destination must have the same "
            "dimensions";
        
        device->CopyTex(dst->metalTexture, 0, 0, src, 0, 0, 0, 0);
        
    } catch (const char *error) {
        blog(LOG_ERROR, "device_stage_texture (Metal): %s", error);
    }
}

void device_begin_frame(gs_device_t *device)
{
    // Do nothing on metal
    UNUSED_PARAMETER(device);
}

void device_begin_scene(gs_device_t *device)
{
    // clear textures
    memset(device->currentTextures, 0, sizeof(device->currentTextures));
    
    device->commandBuffer = [device->commandQueue commandBuffer];
}


void gs_device::SetClear()
{
    ClearState state = clearStates.top().second;
    
    if (state.flags & GS_CLEAR_COLOR) {
        MTLRenderPassColorAttachmentDescriptor *colorAttachment =
        renderPassDescriptor.colorAttachments[0];
        colorAttachment.loadAction = MTLLoadActionClear;
        colorAttachment.clearColor = MTLClearColorMake(
                                                       state.color.x, state.color.y, state.color.z,
                                                       state.color.w);
    } else
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    
    if (state.flags & GS_CLEAR_DEPTH) {
        MTLRenderPassDepthAttachmentDescriptor *depthAttachment =
        renderPassDescriptor.depthAttachment;
        depthAttachment.loadAction = MTLLoadActionClear;
        depthAttachment.clearDepth = state.depth;
    } else
        renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionLoad;
    
    if (state.flags & GS_CLEAR_STENCIL) {
        MTLRenderPassStencilAttachmentDescriptor *stencilAttachment =
        renderPassDescriptor.stencilAttachment;
        stencilAttachment.loadAction   = MTLLoadActionClear;
        stencilAttachment.clearStencil = state.stencil;
    } else
        renderPassDescriptor.stencilAttachment.loadAction = MTLLoadActionLoad;
    
    clearStates.pop();
    if (clearStates.size())
        preserveClearTarget = clearStates.top().first;
    else
        preserveClearTarget = nil;
}

void gs_device::UploadVertexBuffer(id<MTLRenderCommandEncoder> commandEncoder)
{
    vector<id<MTLBuffer>> buffers;
    vector<NSUInteger> offsets;
    
    if (currentVertexBuffer && currentVertexShader) {
        currentVertexBuffer->MakeBufferList(currentVertexShader, buffers);
        if (currentVertexBuffer->isDynamic)
            currentVertexBuffer->Release();
    } else {
        size_t buffersToClear = currentVertexShader ?
        currentVertexShader->NumBuffersExpected() : 0;
        buffers.resize(buffersToClear);
    }
    
    offsets.resize(buffers.size());
    
    [commandEncoder setVertexBuffers:buffers.data()
                             offsets:offsets.data()
                           withRange:NSMakeRange(0, buffers.size())];
    
    lastVertexBuffer = currentVertexBuffer;
    lastVertexShader = currentVertexShader;
}

void gs_device::UploadTextures(id<MTLRenderCommandEncoder> commandEncoder)
{
    for (size_t i = 0; i < GS_MAX_TEXTURES; i++) {
        if (currentTextures[i] == nil)
            break;
        
        [commandEncoder setFragmentTexture:currentTextures[i]->metalTexture atIndex:i];
    }
}

void gs_device::UploadSamplers(id<MTLRenderCommandEncoder> commandEncoder)
{
    for (size_t i = 0; i < GS_MAX_TEXTURES; i++) {
        gs_sampler_state *sampler = currentSamplers[i];
        if (sampler == nil)
            break;
        
        [commandEncoder setFragmentSamplerState:sampler->samplerState
                                        atIndex:i];
    }
}

void gs_device::LoadRasterState(id<MTLRenderCommandEncoder> commandEncoder)
{
    [commandEncoder setViewport:rasterState.mtlViewport];
    /* use CCW to convert to a right-handed coordinate system */
    [commandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    [commandEncoder setCullMode:rasterState.mtlCullMode];
    if (rasterState.scissorEnabled)
        [commandEncoder setScissorRect:rasterState.mtlScissorRect];
}

void gs_device::LoadZStencilState(id<MTLRenderCommandEncoder> commandEncoder)
{
    if (zstencilState.depthEnabled) {
        if (depthStencilState == nil) {
            depthStencilState = [metalDevice newDepthStencilStateWithDescriptor: zstencilState.dsd];
        }
        [commandEncoder setDepthStencilState:depthStencilState];
    }
}

void gs_device::UpdateViewProjMatrix()
{
    gs_matrix_get(&currentViewMatrix);
    
    /* negate Z col of the view matrix for right-handed coordinate system */
    currentViewMatrix.x.z = -currentViewMatrix.x.z;
    currentViewMatrix.y.z = -currentViewMatrix.y.z;
    currentViewMatrix.z.z = -currentViewMatrix.z.z;
    currentViewMatrix.t.z = -currentViewMatrix.t.z;
    
    matrix4_mul(&currentViewProjectionMatrix, &currentViewMatrix, &currentProjectionMatrix);
    matrix4_transpose(&currentViewProjectionMatrix, &currentViewProjectionMatrix);
    
    if (currentVertexShader->viewProjectionMatrix)
        gs_shader_set_matrix4(currentVertexShader->viewProjectionMatrix, &currentViewProjectionMatrix);
}

void gs_device::DrawPrimitives(id<MTLRenderCommandEncoder> commandEncoder,
                               gs_draw_mode drawMode, uint32_t startVert, uint32_t numVerts)
{
    MTLPrimitiveType primitive = ConvertGSTopology(drawMode);
    if (currentIndexBuffer) {
        if (numVerts == 0)
            numVerts = static_cast<uint32_t>(currentIndexBuffer->num);
        [commandEncoder drawIndexedPrimitives:primitive
                                   indexCount:numVerts
                                    indexType:currentIndexBuffer->metalIndexType
                                  indexBuffer:currentIndexBuffer->metalIndexBuffer
                            indexBufferOffset:0];
        if (currentIndexBuffer->isDynamic)
            currentIndexBuffer->metalIndexBuffer = nil;
    } else {
        if (numVerts == 0)
            numVerts = static_cast<uint32_t>(
                                             currentVertexBuffer->vbData->num);
        [commandEncoder drawPrimitives:primitive
                           vertexStart:startVert vertexCount:numVerts];
    }
}

void gs_device::Draw(gs_draw_mode drawMode, uint32_t startVert, uint32_t numVerts)
{
    try {
        if (!currentVertexShader)
            throw "No vertex shader specified";
        if (!currentPixelShader)
            throw "No pixel shader specified";
        
        if (!currentVertexBuffer)
            throw "No vertex buffer specified";
        
        if (!currentRenderTarget)
            throw "No render target to render to";
        
    } catch (const char *error) {
        blog(LOG_ERROR, "device_draw (Metal): %s", error);
        return;
    }
    
    if (renderPipelineState == nil || pipelineStateChanged) {
        NSError *error = nil;
        renderPipelineState = [metalDevice newRenderPipelineStateWithDescriptor:
                               renderPipelineDescriptor error:&error];
        
        if (renderPipelineState == nil) {
            blog(LOG_ERROR, "device_draw (Metal): %s",
                 error.localizedDescription.UTF8String);
            return;
        }
        
        pipelineStateChanged = false;
    }
    
    if (preserveClearTarget != currentRenderTarget) {
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
        renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionLoad;
        renderPassDescriptor.stencilAttachment.loadAction = MTLLoadActionLoad;
    } else
        SetClear();
    
    @autoreleasepool {
        id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [commandEncoder setRenderPipelineState:renderPipelineState];
        
        try {
            gs_effect_t *effect = gs_get_effect();
            if (effect)
                gs_effect_update_params(effect);
            
            LoadRasterState(commandEncoder);
            LoadZStencilState(commandEncoder);
            UpdateViewProjMatrix();
            currentVertexShader->UploadParams(commandEncoder);
            currentPixelShader->UploadParams(commandEncoder);
            UploadVertexBuffer(commandEncoder);
            UploadTextures(commandEncoder);
            UploadSamplers(commandEncoder);
            DrawPrimitives(commandEncoder, drawMode, startVert, numVerts);
            
        } catch (const char *error) {
            blog(LOG_ERROR, "device_draw (Metal): %s", error);
        }
        
        [commandEncoder endEncoding];
    }
}

void device_draw(gs_device_t *device, enum gs_draw_mode draw_mode,
                 uint32_t start_vert, uint32_t num_verts)
{
    /*
     * Do not remove autorelease pool.
     * Add MTLRenderCommandEncoder to autorelease pool.
     */
    @autoreleasepool {
        device->Draw(draw_mode, start_vert, num_verts);
    }
}

inline id<MTLBuffer> gs_device::CreateBuffer(void *data, size_t length)
{
    length = (length + 15) & ~15;
    
    MTLResourceOptions options = MTLResourceCPUCacheModeWriteCombined |
    MTLResourceStorageModeShared;
    id<MTLBuffer> buffer = [metalDevice newBufferWithBytes:data
                                                    length:length options:options];
    if (buffer == nil)
        throw "Failed to create buffer";
    return buffer;
}

id<MTLBuffer> gs_device::GetBuffer(void *data, size_t length)
{
    lock_guard<mutex> lock(mutexObj);
    auto target = find_if(unusedBufferPool.begin(), unusedBufferPool.end(),
                          [length](id<MTLBuffer> b) { return b.length >= length; });
    if (target == unusedBufferPool.end()) {
        id<MTLBuffer> newBuffer = CreateBuffer(data, length);
        curBufferPool.push_back(newBuffer);
        return newBuffer;
    }
    
    id<MTLBuffer> targetBuffer = *target;
    unusedBufferPool.erase(target);
    curBufferPool.push_back(targetBuffer);
    memcpy(targetBuffer.contents, data, length);
    return targetBuffer;
}

void gs_device::PushResources()
{
    lock_guard<mutex> lock(mutexObj);
    bufferPools.push(curBufferPool);
    curBufferPool.clear();
}

void gs_device::ReleaseResources()
{
    lock_guard<mutex> lock(mutexObj);
    auto& pool = bufferPools.front();
    unusedBufferPool.insert(unusedBufferPool.end(),
                            pool.begin(), pool.end());
    bufferPools.pop();
}


void device_end_scene(gs_device_t *device)
{
    /* does nothing in Metal */
    UNUSED_PARAMETER(device);
}

void device_load_swapchain(gs_device_t *device,
                           gs_swapchain_t *swapchain)
{
    if (device->currentSwapChain == swapchain)
        return;
    
    if (swapchain) {
        device->currentSwapChain = swapchain;
        device->currentRenderTarget = swapchain->CurrentTarget();
        
        device->renderPassDescriptor.colorAttachments[0].texture = device->currentSwapChain->metalLayer.nextDrawable.texture;
        device->renderPipelineDescriptor.colorAttachments[0].pixelFormat = device->currentSwapChain->metalLayer.pixelFormat;
    } else {
        device->currentSwapChain = nil;
        device->currentRenderTarget = nil;
        device->renderPassDescriptor.colorAttachments[0].texture = nil;
    }
    
    device->currentRenderSide = 0;
    device->currentZStencilBuffer = nil;
    device->renderPassDescriptor.depthAttachment.texture = nil;
    device->renderPassDescriptor.stencilAttachment.texture = nil;
    
    device->pipelineStateChanged = true;
    blog(LOG_INFO, "device_load_swapchain (Metal): Swapchain loaded");
}

void device_clear(gs_device_t *device, uint32_t clear_flags,
                  const struct vec4 *color, float depth,
                  uint8_t stencil)
{
    device->preserveClearTarget = device->currentRenderTarget;
    
    ClearState state;
    state.flags   = clear_flags;
    state.color   = *color;
    state.depth   = depth;
    state.stencil = stencil;
    device->clearStates.emplace(device->currentRenderTarget, state);
}

void device_present(gs_device_t *device)
{
    if (device->currentSwapChain) {
        [device->commandBuffer presentDrawable:
         device->currentSwapChain->nextDrawable];
    } else {
        blog(LOG_WARNING, "device_present (Metal): No active swap");
    }
    
    device->PushResources();
    
    [device->commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buf) {
        device->ReleaseResources();
        
        UNUSED_PARAMETER(buf);
    }];
    [device->commandBuffer commit];
    device->commandBuffer = nil;
    
    if (device->currentSwapChain)
        device->currentSwapChain->NextTarget();
}

void device_flush(gs_device_t *device)
{
    if (device->commandBuffer != nil) {
        device->PushResources();
        
        [device->commandBuffer commit];
        [device->commandBuffer waitUntilCompleted];
        device->commandBuffer = nil;
        
        device->ReleaseResources();
        
        if (device->currentStageSurface) {
            device->currentStageSurface->DownloadTexture();
            device->currentStageSurface = nil;
        }
    }
}

void device_set_cull_mode(gs_device_t *device, enum gs_cull_mode mode)
{
    if (device->rasterState.cullMode == mode)
        return;
    
    device->rasterState.cullMode = mode;
    
    device->rasterState.mtlCullMode = ConvertGSCullMode(mode);
}

enum gs_cull_mode device_get_cull_mode(const gs_device_t *device)
{
    return device->rasterState.cullMode;
}

void device_enable_blending(gs_device_t *device, bool enable)
{
    if (device->blendState.blendEnabled == enable)
        return;
    
    device->blendState.blendEnabled = enable;
    
    device->renderPipelineDescriptor.colorAttachments[0].blendingEnabled =
    enable ? YES : NO;
    
    device->pipelineStateChanged = true;
}

void device_enable_depth_test(gs_device_t *device, bool enable)
{
    if (device->zstencilState.depthEnabled == enable)
        return;
    
    device->zstencilState.depthEnabled = enable;
    
    device->depthStencilState = nil;
}

void device_enable_stencil_test(gs_device_t *device, bool enable)
{
    ZStencilState &state = device->zstencilState;
    
    if (state.stencilEnabled == enable)
        return;
    
    state.stencilEnabled = enable;
    
    state.dsd.frontFaceStencil.readMask = enable ? 1 : 0;
    state.dsd.backFaceStencil.readMask  = enable ? 1 : 0;
    
    device->depthStencilState = nil;
}

void device_enable_stencil_write(gs_device_t *device, bool enable)
{
    ZStencilState &state = device->zstencilState;
    
    if (state.stencilWriteEnabled == enable)
        return;
    
    state.stencilWriteEnabled = enable;
    
    state.dsd.frontFaceStencil.writeMask = enable ? 1 : 0;
    state.dsd.backFaceStencil.writeMask  = enable ? 1 : 0;
    
    device->depthStencilState = nil;
}

void device_enable_color(gs_device_t *device, bool red, bool green,
                         bool blue, bool alpha)
{
    BlendState &state = device->blendState;
    
    if (state.redEnabled   == red   &&
        state.greenEnabled == green &&
        state.blueEnabled  == blue  &&
        state.alphaEnabled == alpha)
        return;
    
    state.redEnabled   = red;
    state.greenEnabled = green;
    state.blueEnabled  = blue;
    state.alphaEnabled = alpha;
    
    MTLRenderPipelineColorAttachmentDescriptor *cad =
    device->renderPipelineDescriptor.colorAttachments[0];
    cad.writeMask = MTLColorWriteMaskNone;
    if (red)   cad.writeMask |= MTLColorWriteMaskRed;
    if (green) cad.writeMask |= MTLColorWriteMaskGreen;
    if (blue)  cad.writeMask |= MTLColorWriteMaskBlue;
    if (alpha) cad.writeMask |= MTLColorWriteMaskAlpha;
    
    device->pipelineStateChanged = true;
    
}

void device_blend_function(gs_device_t *device, enum gs_blend_type src,
                           enum gs_blend_type dest)
{
    BlendState &state = device->blendState;
    
    if (state.srcFactorC == src && state.destFactorC == dest &&
        state.srcFactorA == src && state.destFactorA == dest)
        return;
    
    state.srcFactorC  = src;
    state.destFactorC = dest;
    state.srcFactorA  = src;
    state.destFactorA = dest;
    
    MTLRenderPipelineColorAttachmentDescriptor *cad =
    device->renderPipelineDescriptor.colorAttachments[0];
    cad.sourceRGBBlendFactor        = ConvertGSBlendType(src);
    cad.destinationRGBBlendFactor   = ConvertGSBlendType(dest);
    cad.sourceAlphaBlendFactor      = ConvertGSBlendType(src);
    cad.destinationAlphaBlendFactor = ConvertGSBlendType(dest);
    
    device->pipelineStateChanged = true;
}

void device_blend_function_separate(gs_device_t *device,
                                    enum gs_blend_type src_c,
                                    enum gs_blend_type dest_c,
                                    enum gs_blend_type src_a,
                                    enum gs_blend_type dest_a)
{
    BlendState &state = device->blendState;
    
    if (state.srcFactorC == src_c && state.destFactorC == dest_c &&
        state.srcFactorA == src_a && state.destFactorA == dest_a)
        return;
    
    state.srcFactorC  = src_c;
    state.destFactorC = dest_c;
    state.srcFactorA  = src_a;
    state.destFactorA = dest_a;
    
    MTLRenderPipelineColorAttachmentDescriptor *cad =
    device->renderPipelineDescriptor.colorAttachments[0];
    cad.sourceRGBBlendFactor        = ConvertGSBlendType(src_c);
    cad.destinationRGBBlendFactor   = ConvertGSBlendType(dest_c);
    cad.sourceAlphaBlendFactor      = ConvertGSBlendType(src_a);
    cad.destinationAlphaBlendFactor = ConvertGSBlendType(dest_a);
    
    device->pipelineStateChanged = true;
}

void device_depth_function(gs_device_t *device, enum gs_depth_test test)
{
    if (device->zstencilState.depthFunc == test)
        return;
    
    device->zstencilState.depthFunc = test;
    
    device->zstencilState.dsd.depthCompareFunction = ConvertGSDepthTest(test);
    
    device->depthStencilState = nil;
}

static inline void update_stencilside_test(gs_device_t *device,
       StencilSide &side, MTLStencilDescriptor *desc,
       gs_depth_test test)
{
   if (side.test == test)
       return;

   side.test = test;

   desc.stencilCompareFunction = ConvertGSDepthTest(test);

   device->depthStencilState = nil;
}

void device_stencil_function(gs_device_t *device,
                             enum gs_stencil_side side,
                             enum gs_depth_test test)
{
    int sideVal = static_cast<int>(side);
    if (sideVal & GS_STENCIL_FRONT)
        update_stencilside_test(device,
                                device->zstencilState.stencilFront,
                                device->zstencilState.dsd.frontFaceStencil,
                                test);
    if (sideVal & GS_STENCIL_BACK)
        update_stencilside_test(device,
                                device->zstencilState.stencilBack,
                                device->zstencilState.dsd.backFaceStencil,
                                test);
    
}

static inline void update_stencilside_op(gs_device_t *device,
                                         StencilSide &side, MTLStencilDescriptor *desc,
                                         enum gs_stencil_op_type fail, enum gs_stencil_op_type zfail,
                                         enum gs_stencil_op_type zpass)
{
    if (side.fail == fail && side.zfail == zfail && side.zpass == zpass)
        return;
    
    side.fail  = fail;
    side.zfail = zfail;
    side.zpass = zpass;
    
    desc.stencilFailureOperation   = ConvertGSStencilOp(fail);
    desc.depthFailureOperation     = ConvertGSStencilOp(zfail);
    desc.depthStencilPassOperation = ConvertGSStencilOp(zpass);
    
    device->depthStencilState = nil;
}

void device_stencil_op(gs_device_t *device, enum gs_stencil_side side,
                       enum gs_stencil_op_type fail,
                       enum gs_stencil_op_type zfail,
                       enum gs_stencil_op_type zpass)
{
    int sideVal = static_cast<int>(side);
    
    if (sideVal & GS_STENCIL_FRONT)
        update_stencilside_op(device,
                              device->zstencilState.stencilFront,
                              device->zstencilState.dsd.frontFaceStencil,
                              fail, zfail, zpass);
    if (sideVal & GS_STENCIL_BACK)
        update_stencilside_op(device,
                              device->zstencilState.stencilBack,
                              device->zstencilState.dsd.backFaceStencil,
                              fail, zfail, zpass);
}

void device_set_viewport(gs_device_t *device, int x, int y, int width,
                         int height)
{
    RasterState &state = device->rasterState;
    
    if (state.viewport.x == x &&
        state.viewport.y == y &&
        state.viewport.cx == width &&
        state.viewport.cy == height)
        return;
    
    state.viewport.x  = x;
    state.viewport.y  = y;
    state.viewport.cx = width;
    state.viewport.cy = height;
    
    state.mtlViewport = ConvertGSRectToMTLViewport(state.viewport);
}

void device_get_viewport(const gs_device_t *device,
                         struct gs_rect *rect)
{
    memcpy(rect, &device->rasterState.viewport, sizeof(gs_rect));
}

void device_set_scissor_rect(gs_device_t *device,
                             const struct gs_rect *rect)
{
    if (rect != nil) {
        device->rasterState.scissorEnabled = true;
        device->rasterState.scissorRect    = *rect;
        device->rasterState.mtlScissorRect =
        ConvertGSRectToMTLScissorRect(*rect);
    } else {
        device->rasterState.scissorEnabled = false;
    }
}

void device_ortho(gs_device_t *device, float left, float right,
                  float top, float bottom, float znear, float zfar)
{
    matrix4 &dst = device->currentProjectionMatrix;
    
    float rml = right - left;
    float bmt = bottom - top;
    float fmn = zfar - znear;
    
    vec4_zero(&dst.x);
    vec4_zero(&dst.y);
    vec4_zero(&dst.z);
    vec4_zero(&dst.t);
    
    dst.x.x =           2.0f /  rml;
    dst.t.x = (left + right) / -rml;
    
    dst.y.y =           2.0f / -bmt;
    dst.t.y = (bottom + top) /  bmt;
    
    dst.z.z =           1.0f /  fmn;
    dst.t.z =          znear / -fmn;
    
    dst.t.w = 1.0f;
}

void device_frustum(gs_device_t *device, float left, float right,
                    float top, float bottom, float znear, float zfar)
{
    matrix4 &dst = device->currentProjectionMatrix;
    
    float rml    = right - left;
    float bmt    = bottom - top;
    float fmn    = zfar - znear;
    float nearx2 = 2.0f * znear;
    
    vec4_zero(&dst.x);
    vec4_zero(&dst.y);
    vec4_zero(&dst.z);
    vec4_zero(&dst.t);
    
    dst.x.x =         nearx2 /  rml;
    dst.z.x = (left + right) / -rml;
    
    dst.y.y =         nearx2 / -bmt;
    dst.z.y = (bottom + top) /  bmt;
    
    dst.z.z =           zfar /  fmn;
    dst.t.z = (znear * zfar) / -fmn;
    
    dst.z.w = 1.0f;
}

void device_projection_push(gs_device_t *device)
{
    device->projectionStack.push(device->currentProjectionMatrix);
}

void device_projection_pop(gs_device_t *device)
{
     if (!device->projectionStack.size())
         return;

     device->currentProjectionMatrix = device->projectionStack.top();
     device->projectionStack.pop();
}

/** Start gs functions
 */

void gs_swapchain_destroy(gs_swapchain_t *swapchain)
{
    assert(swapchain->objectType == GS_SWAP_CHAIN);
    
    if (swapchain == swapchain->device->currentSwapChain)
        device_load_swapchain(swapchain->device, nil);
    
    delete swapchain;
}

void gs_texture_destroy(gs_texture_t *tex)
{
    assert(tex->objectType == GS_TEXTURE);
    delete tex;
}

uint32_t gs_texture_get_width(const gs_texture_t *tex)
{
    assert(tex->objectType == GS_TEXTURE);
    return tex->width;
}

uint32_t gs_texture_get_height(const gs_texture_t *tex)
{
    assert(tex->objectType == GS_TEXTURE);
    return tex->height;
}

enum gs_color_format gs_texture_get_color_format(const gs_texture_t *tex)
{
    assert(tex->objectType == GS_TEXTURE);
    return tex->colorFormat;
}

bool gs_texture_map(gs_texture_t *tex, uint8_t **ptr,
                    uint32_t *linesize)
{
    assert(tex->objectType == GS_TEXTURE);
    assert(tex->textureType == GS_TEXTURE_2D);
    
    *linesize = tex->width * gs_get_format_bpp(tex->colorFormat) / 8;
    uint32_t totalTextureBytes = *linesize * tex->height;
    
    tex->data.resize(1);
    tex->data[0].resize(totalTextureBytes);
    
    *ptr = (uint8_t *)tex->data[0].data();
    
    return true;
}

void gs_texture_unmap(gs_texture_t *tex)
{
    assert(tex->objectType == GS_TEXTURE);
    assert(tex->textureType == GS_TEXTURE_2D);
    
    tex->UploadTexture();
}

void *gs_texture_get_obj(gs_texture_t *tex)
{
    assert(tex->objectType == GS_TEXTURE);
    assert(tex->textureType == GS_TEXTURE_2D);
    
    return (__bridge void*)(tex->metalTexture);
}

void gs_cubetexture_destroy(gs_texture_t *cubetex)
{
    assert(cubetex->textureType == GS_TEXTURE_CUBE);
    delete cubetex;
}

uint32_t gs_cubetexture_get_size(const gs_texture_t *cubetex)
{
    assert(cubetex->textureType == GS_TEXTURE_CUBE);
    return cubetex->width;
}

enum gs_color_format
gs_cubetexture_get_color_format(const gs_texture_t *cubetex)
{
    assert(cubetex->textureType == GS_TEXTURE_CUBE);
    return cubetex->colorFormat;
}

void gs_voltexture_destroy(gs_texture_t *voltex)
{
    assert(voltex->textureType == GS_TEXTURE_3D);
    delete voltex;
}

uint32_t gs_voltexture_get_width(const gs_texture_t *voltex)
{
    assert(voltex->textureType == GS_TEXTURE_3D);
    return voltex->width;
}

uint32_t gs_voltexture_get_height(const gs_texture_t *voltex)
{
    assert(voltex->textureType == GS_TEXTURE_3D);
    return voltex->height;
}

uint32_t gs_voltexture_get_depth(const gs_texture_t *voltex)
{
    assert(voltex->textureType == GS_TEXTURE_3D);
    return voltex->depth;
}

enum gs_color_format
gs_voltexture_get_color_format(const gs_texture_t *voltex)
{
    assert(voltex->textureType == GS_TEXTURE_3D);
    return voltex->colorFormat;
}

void gs_stagesurface_destroy(gs_stagesurf_t *stagesurf)
{
    assert(stagesurf->objectType == GS_STAGE_SURFACE);
    delete stagesurf;
}

uint32_t gs_stagesurface_get_width(const gs_stagesurf_t *stagesurf)
{
    assert(stagesurf->objectType == GS_STAGE_SURFACE);
    return stagesurf->width;
}

uint32_t gs_stagesurface_get_height(const gs_stagesurf_t *stagesurf)
{
    assert(stagesurf->objectType == GS_STAGE_SURFACE);
    return stagesurf->height;
}

enum gs_color_format
gs_stagesurface_get_color_format(const gs_stagesurf_t *stagesurf)
{
    assert(stagesurf->objectType == GS_STAGE_SURFACE);
    return stagesurf->colorFormat;
}

bool gs_stagesurface_map(gs_stagesurf_t *stagesurf, uint8_t **data,
                         uint32_t *linesize)
{
    assert(stagesurf->objectType == GS_STAGE_SURFACE);
    assert(stagesurf->device->commandBuffer != nil);
    
    @autoreleasepool {
        id<MTLBlitCommandEncoder> commandEncoder =
        [stagesurf->device->commandBuffer
         blitCommandEncoder];
        [commandEncoder synchronizeTexture:stagesurf->metalTexture
                                     slice:0 level:0];
        [commandEncoder endEncoding];
    }
    
    *data     = (uint8_t *)stagesurf->textureData.data();
    *linesize = stagesurf->width * gs_get_format_bpp(stagesurf->colorFormat) / 8;

    stagesurf->device->currentStageSurface = stagesurf;
    return true;
}

void gs_stagesurface_unmap(gs_stagesurf_t *stagesurf)
{
    assert(stagesurf->objectType == GS_STAGE_SURFACE);
    
    stagesurf->device->currentStageSurface = nil;
    delete stagesurf;
}

void gs_zstencil_destroy(gs_zstencil_t *zstencil)
{
    assert(zstencil->objectType == GS_ZSTENCIL_BUFFER);
    
    delete zstencil;
}

void gs_samplerstate_destroy(gs_samplerstate_t *samplerstate)
{
    assert(samplerstate->objectType == GS_SAMPLER_STATE);
    
    if (samplerstate->device) {
        for (size_t i = 0; i < GS_MAX_TEXTURES; i++)
            if (samplerstate->device->currentSamplers[i] ==
                samplerstate)
                samplerstate->device->currentSamplers[i] = nil;
    }
    
    delete samplerstate;
}

void gs_vertexbuffer_destroy(gs_vertbuffer_t *vertbuffer)
{
    assert(vertbuffer->objectType == GS_VERTEX_BUFFER);
    
    if (vertbuffer->device->lastVertexBuffer == vertbuffer)
        vertbuffer->device->lastVertexBuffer = nil;
    
    delete vertbuffer;
}

void gs_vertexbuffer_flush(gs_vertbuffer_t *vertbuffer)
{
    assert(vertbuffer->objectType == GS_VERTEX_BUFFER);
    
    if (!vertbuffer->isDynamic) {
        blog(LOG_ERROR, "gs_vertexbuffer_flush: vertex buffer is not "
             "dynamic");
        return;
    }
    
    vertbuffer->PrepareBuffers();
}

void gs_vertexbuffer_flush_direct(gs_vertbuffer_t *vertbuffer,
                                  const struct gs_vb_data *data)
{
    assert(vertbuffer->objectType == GS_VERTEX_BUFFER);
    
    if (!vertbuffer->isDynamic) {
        blog(LOG_ERROR, "gs_vertexbuffer_flush_direct: vertex buffer is not "
             "dynamic");
        return;
    }
    vertbuffer->vbData.reset((gs_vb_data *)data);
    vertbuffer->PrepareBuffers();
}

struct gs_vb_data *gs_vertexbuffer_get_data(const gs_vertbuffer_t *vertbuffer)
{
    assert(vertbuffer->objectType == GS_VERTEX_BUFFER);
    return vertbuffer->vbData.get();
}

void gs_indexbuffer_destroy(gs_indexbuffer_t *indexbuffer)
{
    assert(indexbuffer->objectType == GS_INDEX_BUFFER);
    delete indexbuffer;

}

void gs_indexbuffer_flush(gs_indexbuffer_t *indexbuffer)
{
    assert(indexbuffer->objectType == GS_INDEX_BUFFER);
    
    if (!indexbuffer->isDynamic) {
        blog(LOG_ERROR, "gs_indexbuffer_flush: index buffer is not "
             "dynamic");
        return;
    }
    
    indexbuffer->PrepareBuffer();
}

void gs_indexbuffer_flush_direct(gs_indexbuffer_t *indexbuffer,
                                 const void *data)
{
    assert(indexbuffer->objectType == GS_INDEX_BUFFER);
       
       if (!indexbuffer->isDynamic) {
           blog(LOG_ERROR, "gs_indexbuffer_flush_direct: index buffer is not "
                "dynamic");
           return;
       }
    
       indexbuffer->indices.reset((void *)data);
       indexbuffer->PrepareBuffer();
}

void *gs_indexbuffer_get_data(const gs_indexbuffer_t *indexbuffer)
{
    assert(indexbuffer->objectType == GS_INDEX_BUFFER);
    return indexbuffer->indices.get();
}

size_t gs_indexbuffer_get_num_indices(const gs_indexbuffer_t *indexbuffer)
{
    assert(indexbuffer->objectType == GS_INDEX_BUFFER);
    return indexbuffer->num;
}

enum gs_index_type gs_indexbuffer_get_type(const gs_indexbuffer_t *indexbuffer)
{
    assert(indexbuffer->objectType == GS_INDEX_BUFFER);
    return indexbuffer->indexType;
}

void gs_timer_destroy(gs_timer_t *timer)
{
    UNUSED_PARAMETER(timer);
}

void gs_timer_begin(gs_timer_t *timer)
{
    UNUSED_PARAMETER(timer);
}

void gs_timer_end(gs_timer_t *timer)
{
    UNUSED_PARAMETER(timer);
}

bool gs_timer_get_data(gs_timer_t *timer, uint64_t *ticks)
{
    UNUSED_PARAMETER(timer);
    UNUSED_PARAMETER(ticks);
    return false;
}

void gs_timer_range_destroy(gs_timer_range_t *timer)
{
    UNUSED_PARAMETER(timer);
}

void gs_timer_range_begin(gs_timer_range_t *range)
{
    UNUSED_PARAMETER(range);
}

void gs_timer_range_end(gs_timer_range_t *range)
{
    UNUSED_PARAMETER(range);
}

bool gs_timer_range_get_data(gs_timer_range_t *range, bool *disjoint,
                             uint64_t *frequency) {
    UNUSED_PARAMETER(range);
    UNUSED_PARAMETER(disjoint);
    UNUSED_PARAMETER(frequency);
    return false;
}

bool device_nv12_available(gs_device_t *device) {
    UNUSED_PARAMETER(device);
    return true;
}




/** Start device_debug functions
 */

void device_debug_marker_begin(gs_device_t *device,
                               const char *markername,
                               const float color[4])
{
    UNUSED_PARAMETER(device);
    UNUSED_PARAMETER(markername);
    UNUSED_PARAMETER(color);

}

void device_debug_marker_end(gs_device_t *device)
{
    UNUSED_PARAMETER(device);
}
