#include "metal-subsystem.hpp"

/** Start gs_swap_chain functions
 */

gs_swap_chain::gs_swap_chain(gs_device *device, const gs_init_data *data)
 : gs_object(device, GS_SWAP_CHAIN),
view(data->window.view)
{
    metalLayer = [CAMetalLayer layer];
    metalLayer.device = device->metalDevice;
    metalLayer.drawableSize = CGSizeMake(data->cx, data->cy);
    view.wantsLayer = true;
    view.layer = metalLayer;
}
