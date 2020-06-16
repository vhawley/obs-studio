#include "metal-subsystem.hpp"

gs_sampler_state::gs_sampler_state(gs_device_t *device, const gs_sampler_info *info)
: gs_object(device, GS_SAMPLER_STATE),
info(*info)
{
    // Create metal sampler descriptor
}
