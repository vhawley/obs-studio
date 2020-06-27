#include "metal-subsystem.hpp"

gs_zstencil_buffer::gs_zstencil_buffer(gs_device_t *device, uint32_t width, uint32_t height, gs_zstencil_format format)
: gs_object(device, GS_ZSTENCIL_BUFFER),
width(width),
height(height),
zStencilFormat(format)
{
    textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:
                   ConvertGSZStencilFormat(format) width:width height:height mipmapped:NO];
    textureDescriptor.cpuCacheMode = MTLCPUCacheModeWriteCombined;
    textureDescriptor.storageMode  = MTLStorageModeManaged;
    
    InitBuffer();
}

void gs_zstencil_buffer::InitBuffer()
{
   metalTexture = [device->metalDevice newTextureWithDescriptor:textureDescriptor];
   if (metalTexture == nil)
       throw "Failed to create depth stencil texture";

 #if _DEBUG
   metalTexture.label = @"zstencil";
#endif
}
