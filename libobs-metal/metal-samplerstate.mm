#include "metal-subsystem.hpp"

gs_sampler_state::gs_sampler_state(gs_device_t *device, const gs_sampler_info *info)
: gs_object(device, GS_SAMPLER_STATE),
info(*info)
{
    InitSampler();
}

void gs_sampler_state::InitSampler()
{
    samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
    samplerDescriptor.sAddressMode    = ConvertGSAddressMode(info.address_u);
    samplerDescriptor.tAddressMode    = ConvertGSAddressMode(info.address_v);
    samplerDescriptor.rAddressMode    = ConvertGSAddressMode(info.address_w);
    samplerDescriptor.minFilter       = ConvertGSMinFilter(info.filter);
    samplerDescriptor.magFilter       = ConvertGSMagFilter(info.filter);
    samplerDescriptor.mipFilter       = ConvertGSMipFilter(info.filter);
    samplerDescriptor.maxAnisotropy   = min(max(info.max_anisotropy, 1), 16);
    samplerDescriptor.compareFunction = MTLCompareFunctionAlways;
    
    if ((info.border_color & 0x000000FF) == 0)
        samplerDescriptor.borderColor = MTLSamplerBorderColorTransparentBlack;
    else if (info.border_color == 0xFFFFFFFF)
        samplerDescriptor.borderColor = MTLSamplerBorderColorOpaqueWhite;
    else
        samplerDescriptor.borderColor = MTLSamplerBorderColorOpaqueBlack;
    
    
    samplerState = [device->metalDevice
                    newSamplerStateWithDescriptor:samplerDescriptor];
    if (samplerState == nil)
        throw "Failed to create sampler state";
}
