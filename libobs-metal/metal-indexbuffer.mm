#include "metal-subsystem.hpp"

gs_index_buffer::gs_index_buffer(gs_device_t *device, gs_index_type type, void *indices, size_t num, uint32_t flags)
: gs_object(device, GS_INDEX_BUFFER),
type(type),
indices(indices),
num(num),
flags(flags)
{
    // Create MTLBuffer
}
