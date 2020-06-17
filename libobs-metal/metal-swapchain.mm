#include "metal-subsystem.hpp"

/** Start gs_swap_chain functions
 */

gs_swap_chain::gs_swap_chain(gs_device *device, const gs_init_data *data)
: gs_object(device, GS_SWAP_CHAIN),
initData(data),
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
    blog(LOG_INFO, [[device->metalDevice name] UTF8String]);
    if (nextTarget == nil)
        return NextTarget();
    return nextTarget;
}

gs_texture *gs_swap_chain::NextTarget()
{
    if (metalLayer.nextDrawable != nil)
        nextTarget = new gs_texture(device, [[metalLayer nextDrawable] texture]);
    
    return nextTarget;
}
