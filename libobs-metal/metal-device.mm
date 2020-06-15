#include "metal-device.hpp"

gs_device::gs_device(uint32_t adapter) {
    NSArray *metalDevices = MTLCopyAllDevices();
    
    device_index = adapter;
    
    NSUInteger numDevices = [metalDevices count];
    if (!metalDevices || numDevices < 1 || adapter > numDevices - 1) {
        throw "Failed to get Metal devices";
    }
    
    device = [metalDevices objectAtIndex:device_index];
    render_pass_descriptor = [[MTLRenderPassDescriptor alloc] init];
    render_pipeline_descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    command_queue = [device newCommandQueue];
}
