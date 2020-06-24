#include "metal-subsystem.hpp"

/** Start gs_swap_chain functions
 */

gs_swap_chain::gs_swap_chain(gs_device *device, const gs_init_data *data)
: gs_object(device, GS_SWAP_CHAIN),
initData(const_cast<gs_init_data *>(data)),
view(data->window.view),
nextTarget(nil)
{
    metalLayer = [CAMetalLayer layer];
    metalLayer.device = device->metalDevice;
    metalLayer.drawableSize = CGSizeMake(data->cx, data->cy);
    view.wantsLayer = true;
    view.layer = metalLayer;
}

gs_texture *gs_swap_chain::CurrentTarget()
{
    if (nextTarget == nil)
        return NextTarget();
    return nextTarget;
}

gs_texture *gs_swap_chain::NextTarget()
{
    nextDrawable = [metalLayer nextDrawable];
    if (nextDrawable != nil)
        nextTarget = new gs_texture(device, [[metalLayer nextDrawable] texture]);
    
    return nextTarget;
}

void gs_swap_chain::Resize(uint32_t cx, uint32_t cy)
{
    initData->cx = cx;
    initData->cy = cy;
    
    if (cx == 0 || cy == 0) {
        NSRect clientRect = view.layer.frame;
        if (cx == 0) cx = clientRect.size.width - clientRect.origin.x;
        if (cy == 0) cy = clientRect.size.height - clientRect.origin.y;
    }
    
    metalLayer.drawableSize = CGSizeMake(cx, cy);
}

void gs_swap_chain::Rebuild()
{
    metalLayer.device = device->metalDevice;
}
