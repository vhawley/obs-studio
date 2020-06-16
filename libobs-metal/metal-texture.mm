#include "metal-subsystem.hpp"

gs_texture::gs_texture(gs_device_t *device, uint32_t width, uint32_t height, gs_color_format color_format, uint32_t levels, const uint8_t **data, uint32_t flags, gs_texture_type texture_type)
: gs_object(device, GS_TEXTURE),
width(width),
height(height),
color_format(color_format),
levels(levels),
data(data),
flags(flags),
texture_type(texture_type)
{
    // TODO
}
