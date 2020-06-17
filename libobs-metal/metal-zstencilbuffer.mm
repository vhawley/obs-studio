#include "metal-subsystem.hpp"

gs_zstencil_buffer::gs_zstencil_buffer(gs_device_t *device, uint32_t width, uint32_t height, gs_zstencil_format format)
: gs_object(device, GS_ZSTENCIL_BUFFER),
width(width),
height(height),
zStencilFormat(format)
{
    // Create MTLBuffer
}
