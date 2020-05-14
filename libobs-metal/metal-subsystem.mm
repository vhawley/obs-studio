#include "metal-subsystem.hpp"

const char *device_get_name(void) {
    return "Metal";
}

int device_get_type(void) {
    return GS_DEVICE_METAL;
}
