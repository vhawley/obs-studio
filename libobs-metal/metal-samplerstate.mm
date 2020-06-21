#include "metal-subsystem.hpp"

gs_sampler_state::gs_sampler_state(gs_device_t *device, const gs_sampler_info *info)
: gs_object(device, GS_SAMPLER_STATE),
info(*info)
{
    InitSampler();
}

void gs_sampler_state::InitSampler()
{
    samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.sAddressMode    = ConvertGSAddressMode(info.address_u);
    samplerDesc.tAddressMode    = ConvertGSAddressMode(info.address_v);
    samplerDesc.rAddressMode    = ConvertGSAddressMode(info.address_w);
    samplerDesc.minFilter       = ConvertGSMinFilter(info.filter);
    samplerDesc.magFilter       = ConvertGSMagFilter(info.filter);
    samplerDesc.mipFilter       = ConvertGSMipFilter(info.filter);
    samplerDesc.maxAnisotropy   = min(max(info.max_anisotropy, 1), 16);
    samplerDesc.compareFunction = MTLCompareFunctionAlways;
    
    if ((info.border_color & 0x000000FF) == 0)
        samplerDesc.borderColor = MTLSamplerBorderColorTransparentBlack;
    else if (info.border_color == 0xFFFFFFFF)
        samplerDesc.borderColor = MTLSamplerBorderColorOpaqueWhite;
    else
        samplerDesc.borderColor = MTLSamplerBorderColorOpaqueBlack;
    
    
    samplerState = [device->metalDevice
                    newSamplerStateWithDescriptor:samplerDesc];
    if (samplerState == nil)
        throw "Failed to create sampler state";
}
