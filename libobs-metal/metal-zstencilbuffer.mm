#include "metal-subsystem.hpp"

static inline MTLPixelFormat ConvertGSZStencilFormat(gs_zstencil_format format)
{
   switch (format) {
   case GS_ZS_NONE:    return MTLPixelFormatInvalid;
   case GS_Z16:        return MTLPixelFormatDepth16Unorm;
   case GS_Z24_S8:     return MTLPixelFormatDepth24Unorm_Stencil8;
   case GS_Z32F:       return MTLPixelFormatDepth32Float;
   case GS_Z32F_S8X24: return MTLPixelFormatDepth32Float_Stencil8;
   default:            throw "Failed to initialize zstencil buffer";
   }

   return MTLPixelFormatInvalid;
}

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
