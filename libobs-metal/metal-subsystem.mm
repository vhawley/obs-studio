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
    if (!(device->currentSwapChain)) {
        blog(LOG_ERROR, "device_resize (Metal): No swap chain");
        return;
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
        texture = new gs_texture(device, width, height, color_format, levels, data, flags, GS_TEXTURE_2D);
    } catch (const char *error) {
        blog(LOG_ERROR, "device_texture_create (Metal): %s", error);
    }
    
    return texture;
}

gs_texture_t *device_cubetexture_create(gs_device_t *device, uint32_t size,
                                        enum gs_color_format color_format, uint32_t levels,
                                        const uint8_t **data, uint32_t flags)
{
    
}

gs_texture_t *device_voltexture_create(gs_device_t *device, uint32_t width, uint32_t height,
                                       uint32_t depth, enum gs_color_format color_format,
                                       uint32_t levels, const uint8_t *const *data,
                                       uint32_t flags)
{
    
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
    
}

gs_samplerstate_t *
device_samplerstate_create(gs_device_t *device,
                           const struct gs_sampler_info *info)
{
    
}

gs_shader_t *device_vertexshader_create(gs_device_t *device,
                                        const char *shader,
                                        const char *file,
                                        char **error_string)
{
    gs_shader *vertex_shader;
    
    try {
        vertex_shader = new gs_shader(device, shader, file, GS_SHADER_VERTEX);
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
    gs_shader *pixel_shader;
    
    try {
        pixel_shader = new gs_shader(device, shader, file, GS_SHADER_PIXEL);
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
        blog(LOG_ERROR, "device_vertexbuffer_create (Metal): %s",
             error);
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
    assert(device != NULL);
    assert(unit >= 0);
    assert(unit < GS_MAX_TEXTURES);
    if (device->currentSamplers[unit] != samplerstate)
        device->currentSamplers[unit] = samplerstate;
}

void device_load_vertexshader(gs_device_t *device,
                              gs_shader_t *vertshader)
{
    assert(device != NULL);
    if (device->currentVertexShader != vertshader)
        device->currentVertexShader = vertshader;
}

void device_load_pixelshader(gs_device_t *device,
                             gs_shader_t *pixelshader)
{
    
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
    
}

gs_zstencil_t *device_get_zstencil_target(const gs_device_t *device)
{
}

void device_set_render_target(gs_device_t *device, gs_texture_t *tex,
                              gs_zstencil_t *zstencil)
{
    
}

void device_set_cube_render_target(gs_device_t *device,
                                   gs_texture_t *cubetex, int side,
                                   gs_zstencil_t *zstencil)
{
    
}

void device_copy_texture(gs_device_t *device, gs_texture_t *dst,
                         gs_texture_t *src)
{
    
}

void device_copy_texture_region(gs_device_t *device, gs_texture_t *dst,
                                uint32_t dst_x, uint32_t dst_y,
                                gs_texture_t *src, uint32_t src_x,
                                uint32_t src_y, uint32_t src_w,
                                uint32_t src_h)
{
    
}

void device_stage_texture(gs_device_t *device, gs_stagesurf_t *dst,
                          gs_texture_t *src)
{
    
}

void device_begin_frame(gs_device_t *device)
{
    
}

void device_begin_scene(gs_device_t *device)
{
    
}

void device_draw(gs_device_t *device, enum gs_draw_mode draw_mode,
                 uint32_t start_vert, uint32_t num_verts)
{
    
}

void device_end_scene(gs_device_t *device)
{
    
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
}

void device_clear(gs_device_t *device, uint32_t clear_flags,
                  const struct vec4 *color, float depth,
                  uint8_t stencil)
{
    
}

void device_present(gs_device_t *device)
{
    
}

void device_flush(gs_device_t *device)
{
    
}

void device_set_cull_mode(gs_device_t *device, enum gs_cull_mode mode)
{
    
}

enum gs_cull_mode device_get_cull_mode(const gs_device_t *device)
{
    
}

void device_enable_blending(gs_device_t *device, bool enable)
{
    
}

void device_enable_depth_test(gs_device_t *device, bool enable)
{
    
}

void device_enable_stencil_test(gs_device_t *device, bool enable)
{
    
}

void device_enable_stencil_write(gs_device_t *device, bool enable)
{
    
}

void device_enable_color(gs_device_t *device, bool red, bool green,
                         bool blue, bool alpha)
{
    
}

void device_blend_function(gs_device_t *device, enum gs_blend_type src,
                           enum gs_blend_type dest)
{
    
}

void device_blend_function_separate(gs_device_t *device,
                                    enum gs_blend_type src_c,
                                    enum gs_blend_type dest_c,
                                    enum gs_blend_type src_a,
                                    enum gs_blend_type dest_a)
{
    
}

void device_depth_function(gs_device_t *device, enum gs_depth_test test)
{
    
}

void device_stencil_function(gs_device_t *device,
                             enum gs_stencil_side side,
                             enum gs_depth_test test)
{
    
}

void device_stencil_op(gs_device_t *device, enum gs_stencil_side side,
                       enum gs_stencil_op_type fail,
                       enum gs_stencil_op_type zfail,
                       enum gs_stencil_op_type zpass)
{
    
}

void device_set_viewport(gs_device_t *device, int x, int y, int width,
                         int height)
{
    
}

void device_get_viewport(const gs_device_t *device,
                         struct gs_rect *rect)
{
    
}

void device_set_scissor_rect(gs_device_t *device,
                             const struct gs_rect *rect)
{
    
}

void device_ortho(gs_device_t *device, float left, float right,
                  float top, float bottom, float znear, float zfar)
{
    
}

void device_frustum(gs_device_t *device, float left, float right,
                    float top, float bottom, float znear, float zfar)
{
    
}

void device_projection_push(gs_device_t *device)
{
    
}

void device_projection_pop(gs_device_t *device)
{
    
}

/** Start gs functions
 */

void gs_swapchain_destroy(gs_swapchain_t *swapchain)
{
    assert(swapchain->objectType == GS_SWAP_CHAIN);
    
    if (swapchain == swapchain->device->currentSwapChain)
         device_load_swapchain(swapchain->device, nullptr);

    delete swapchain;
}

void gs_texture_destroy(gs_texture_t *tex)
{
    
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
    *ptr = (uint8_t*)malloc(sizeof(uint8_t) * tex->height * *linesize);
    return true;
}

void gs_texture_unmap(gs_texture_t *tex)
{
    assert(tex->objectType == GS_TEXTURE);
    assert(tex->textureType == GS_TEXTURE_2D);
    
    
}

void *gs_texture_get_obj(gs_texture_t *tex)
{
    assert(tex->objectType == GS_TEXTURE);
    assert(tex->textureType == GS_TEXTURE_2D);
    
    return tex->metalTexture;
}

void gs_cubetexture_destroy(gs_texture_t *cubetex)
{
    
}

uint32_t gs_cubetexture_get_size(const gs_texture_t *cubetex)
{
    
}

enum gs_color_format
gs_cubetexture_get_color_format(const gs_texture_t *cubetex)
{
    
}

void gs_voltexture_destroy(gs_texture_t *voltex)
{
    
}

uint32_t gs_voltexture_get_width(const gs_texture_t *voltex)
{
    
}

uint32_t gs_voltexture_get_height(const gs_texture_t *voltex)
{
    
}

uint32_t gs_voltexture_get_depth(const gs_texture_t *voltex)
{
    
}

enum gs_color_format
gs_voltexture_get_color_format(const gs_texture_t *voltex)
{
    
}

void gs_stagesurface_destroy(gs_stagesurf_t *stagesurf)
{
    
}

uint32_t gs_stagesurface_get_width(const gs_stagesurf_t *stagesurf)
{
    
}

uint32_t gs_stagesurface_get_height(const gs_stagesurf_t *stagesurf)
{
    
}

enum gs_color_format
gs_stagesurface_get_color_format(const gs_stagesurf_t *stagesurf)
{
    
}

bool gs_stagesurface_map(gs_stagesurf_t *stagesurf, uint8_t **data,
                         uint32_t *linesize)
{
    
}

void gs_stagesurface_unmap(gs_stagesurf_t *stagesurf)
{
    
}

void gs_zstencil_destroy(gs_zstencil_t *zstencil)
{
    
}

void gs_samplerstate_destroy(gs_samplerstate_t *samplerstate)
{
    
}

void gs_vertexbuffer_destroy(gs_vertbuffer_t *vertbuffer)
{
    
}

void gs_vertexbuffer_flush(gs_vertbuffer_t *vertbuffer)
{
    
}

void gs_vertexbuffer_flush_direct(gs_vertbuffer_t *vertbuffer,
                                  const struct gs_vb_data *data)
{
    
}

struct gs_vb_data *gs_vertexbuffer_get_data(const gs_vertbuffer_t *vertbuffer)
{
    assert(vertbuffer->objectType == GS_VERTEX_BUFFER);
    return vertbuffer->data;
}

void gs_indexbuffer_destroy(gs_indexbuffer_t *indexbuffer)
{
    
}

void gs_indexbuffer_flush(gs_indexbuffer_t *indexbuffer)
{
    
}

void gs_indexbuffer_flush_direct(gs_indexbuffer_t *indexbuffer,
                                 const void *data)
{
    
}

void *gs_indexbuffer_get_data(const gs_indexbuffer_t *indexbuffer)
{
    
}

size_t gs_indexbuffer_get_num_indices(const gs_indexbuffer_t *indexbuffer)
{
    
}

enum gs_index_type gs_indexbuffer_get_type(const gs_indexbuffer_t *indexbuffer)
{
    
}

void gs_timer_destroy(gs_timer_t *timer)
{
    
}

void gs_timer_begin(gs_timer_t *timer)
{
    
}

void gs_timer_end(gs_timer_t *timer)
{
    
}

bool gs_timer_get_data(gs_timer_t *timer, uint64_t *ticks)
{
    
}

void gs_timer_range_destroy(gs_timer_range_t *timer)
{
    
}

void gs_timer_range_begin(gs_timer_range_t *range)
{
    
}

void gs_timer_range_end(gs_timer_range_t *range)
{
    
}

bool gs_timer_range_get_data(gs_timer_range_t *range, bool *disjoint,
                             uint64_t *frequency) {
    
}



/** Start device_debug functions
 */

void device_debug_marker_begin(gs_device_t *device,
                               const char *markername,
                               const float color[4])
{
    
}

void device_debug_marker_end(gs_device_t *device)
{
    
}
