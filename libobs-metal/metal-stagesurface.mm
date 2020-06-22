#include "metal-subsystem.hpp"

gs_stage_surface::gs_stage_surface(gs_device_t *device, uint32_t width, uint32_t height, gs_color_format color_format)
: gs_object(device, GS_STAGE_SURFACE),
width(width),
height(height),
colorFormat(color_format)
{
    textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:
            ConvertGSTextureFormat(colorFormat)
            width:width height:height mipmapped:NO];
    textureDescriptor.storageMode = MTLStorageModeManaged;
    
    uint32_t bytesPerRow = width * gs_get_format_bpp(colorFormat) / 8;
    textureData.resize(height * bytesPerRow);
    
    InitTexture();
}

void gs_stage_surface::DownloadTexture()
{
    MTLRegion from = MTLRegionMake2D(0, 0, width, height);
    uint32_t bytesPerRow = width * gs_get_format_bpp(colorFormat) / 8;
    [metalTexture getBytes:textureData.data() bytesPerRow:bytesPerRow
                fromRegion:from mipmapLevel:0];
}

void gs_stage_surface::InitTexture()
{
    metalTexture = [device->metalDevice newTextureWithDescriptor:textureDescriptor];
    if (metalTexture == nil)
        throw "Failed to create staging surface";
}
