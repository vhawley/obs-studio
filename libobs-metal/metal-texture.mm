#include "metal-subsystem.hpp"

// Init from data
gs_texture::gs_texture(gs_device_t *device, uint32_t width, uint32_t height, uint32_t depth, gs_color_format colorFormat, uint32_t levels, const uint8_t **data, uint32_t flags, gs_texture_type textureType)
: gs_object(device, GS_TEXTURE),
width(width),
height(height),
depth(depth),
colorFormat(colorFormat),
levels(levels),
isRenderTarget((flags & GS_RENDER_TARGET) != 0),
isDynamic((flags & GS_DYNAMIC) != 0),
isShared((flags & (GS_SHARED_TEX | GS_SHARED_KM_TEX)) != 0),
genMipmaps((flags & GS_BUILD_MIPMAPS) != 0),
textureType(textureType),
metalPixelFormat(ConvertGSTextureFormat(colorFormat))
{
    InitTextureDescriptor();
    
    InitTexture();
    
    if (data) {
        BackupTexture(data);
        UploadTexture();
        if (genMipmaps)
            GenerateMipmap();
    }
}

// Init from MTLTexture
gs_texture::gs_texture(gs_device_t *device, id<MTLTexture> texture)
: gs_object(device, GS_TEXTURE),
width(texture.width),
height(texture.height),
isRenderTarget(false),
isDynamic(false),
isShared(true),
genMipmaps(false),
metalTexture (texture),
metalPixelFormat(texture.pixelFormat)
{
}

void gs_texture::InitTextureDescriptor() {
    // Setup texture descriptor
    switch(textureType) {
        case GS_TEXTURE_CUBE: {
            NSUInteger size = 6 * width * height;
            metalTextureDescriptor = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:metalPixelFormat size:size mipmapped:genMipmaps];
            metalTextureDescriptor.textureType = MTLTextureTypeCube;
            break;
        }
        case GS_TEXTURE_2D: {
            metalTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: metalPixelFormat width:width height:height mipmapped:genMipmaps];
            metalTextureDescriptor.textureType = MTLTextureType2D;
            break;
        }
        case GS_TEXTURE_3D: {
            metalTextureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: metalPixelFormat width:width height:height mipmapped:genMipmaps];
            metalTextureDescriptor.textureType = MTLTextureType3D;
            break;
        }
        default: {
            blog(LOG_ERROR, "Invalid texture type");
            throw;
        }
    }
    if (genMipmaps)
        metalTextureDescriptor.mipmapLevelCount = levels;
    
    metalTextureDescriptor.arrayLength = textureType == GS_TEXTURE_CUBE ? 6 : 1;
    metalTextureDescriptor.cpuCacheMode = MTLCPUCacheModeWriteCombined;
    metalTextureDescriptor.storageMode = MTLStorageModeManaged;
    metalTextureDescriptor.usage = MTLTextureUsageShaderRead;
    
    if (isRenderTarget)
        metalTextureDescriptor.usage |= MTLTextureUsageRenderTarget;
}

void gs_texture::RebuildTextureDescriptor()
{
    metalTextureDescriptor = nil;
    
    InitTextureDescriptor();
}

void gs_texture::InitTexture()
{
    assert(!isShared);
    assert(metalTextureDescriptor != nil);
    
    metalTexture = [device->metalDevice newTextureWithDescriptor:metalTextureDescriptor];
    if (metalTexture == nil)
        throw "Failed to create 2D texture";
}

void gs_texture::RebuildTexture()
{
    if (isShared) {
        metalTexture = nil;
        return;
    }
    
    InitTexture();
}

void gs_texture::GenerateMipmap()
{
    assert(device->commandBuffer == nil);
    
    if (levels == 1)
        return;
    
    @autoreleasepool {
        id<MTLCommandBuffer> buf = [device->commandQueue commandBuffer];
        id<MTLBlitCommandEncoder> blit = [buf blitCommandEncoder];
        [blit generateMipmapsForTexture:metalTexture];
        [blit endEncoding];
        [buf commit];
        [buf waitUntilCompleted];
    }
}


void gs_texture::BackupTexture(const uint8_t **data) {
    this->data.resize(levels);
    
    uint32_t w = width;
    uint32_t h = height;
    uint32_t bytes_per_pixel = gs_get_format_bpp(colorFormat) / 8;
    
    for (uint32_t i = 0; i < levels; i++) {
        if (!data[i])
            break;
        
        uint32_t texSize = bytes_per_pixel * w * h;
        this->data[i].resize(texSize);
        
        auto &subData = this->data[i];
        memcpy(&subData[0], data[i], texSize);
        
        w /= 2;
        h /= 2;
    }
}

void gs_texture::UploadTexture()
{
    assert(metalTexture != nil);
    const uint32_t bytes_per_pixel = gs_get_format_bpp(colorFormat) / 8;
    uint32_t w = width;
    uint32_t h = height;
    
    for (uint32_t i = 0; i < levels; i++) {
        if (i >= data.size())
            break;
        
        const uint32_t bytes_per_row = w * bytes_per_pixel;
        const uint32_t total_texture_bytes = h * bytes_per_row;
        MTLRegion region = MTLRegionMake2D(0, 0, w, h);
        uint8_t *raw = data[i].data();
        [metalTexture replaceRegion:region mipmapLevel:i slice:0
                          withBytes:raw
                        bytesPerRow:bytes_per_row
                      bytesPerImage:total_texture_bytes];
        
        w /= 2;
        h /= 2;
    }
}
