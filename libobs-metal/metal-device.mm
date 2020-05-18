#include "metal-device.hpp"

gs_device::gs_device(uint32_t adapter) {
    NSArray *metalDevices = MTLCopyAllDevices();
    
    deviceIndex = adapter;
    
    NSUInteger numDevices = [metalDevices count];
    if (!metalDevices || numDevices < 1 || adapter > numDevices - 1) {
        throw "Failed to get Metal devices";
    }
    
    device = [metalDevices objectAtIndex:deviceIndex];
    renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
    renderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    commandQueue = [device newCommandQueue];
}
