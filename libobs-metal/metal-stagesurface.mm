#include "metal-subsystem.hpp"

gs_stage_surface::gs_stage_surface(gs_device_t *device, uint32_t width, uint32_t height, gs_color_format color_format)
: gs_object(device, GS_STAGE_SURFACE),
width(width),
height(height),
color_format(color_format)
{
    
}
