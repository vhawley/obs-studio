#include "metal-subsystem.hpp"

gs_vertex_buffer::gs_vertex_buffer(gs_device_t *device, struct gs_vb_data *data, uint32_t flags)
: gs_object(device, GS_VERTEX_BUFFER),
    data(data),
    flags(flags)
{
    // Create MTLBuffer
}
