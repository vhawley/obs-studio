#include "metal-subsystem.hpp"

static inline MTLIndexType ConvertGSIndexType(gs_index_type type)
{
   switch (type) {
       case GS_UNSIGNED_SHORT: return MTLIndexTypeUInt16;
       case GS_UNSIGNED_LONG:  return MTLIndexTypeUInt32;
   }

   throw "Failed to initialize index buffer";
}

 static inline size_t ConvertGSIndexTypeToSize(gs_index_type type)
{
   switch (type) {
       case GS_UNSIGNED_SHORT: return 2;
       case GS_UNSIGNED_LONG:  return 4;
   }

   throw "Failed to initialize index buffer";
}

gs_index_buffer::gs_index_buffer(gs_device_t *device, gs_index_type indexType, void *indices, size_t num, uint32_t flags)
: gs_object(device, GS_INDEX_BUFFER),
indexType(indexType),
indices(indices),
num(num),
len(ConvertGSIndexTypeToSize(indexType) * num),
isDynamic((flags & GS_DYNAMIC) != 0),
metalIndexType(ConvertGSIndexType(indexType))
{
    if (!isDynamic)
        InitBuffer();
}

void gs_index_buffer::FlushBuffer(void *new_indices)
{
    assert(isDynamic);
    
    if (indices != nullptr && indices != new_indices) {
        bfree(indices);
        indices = new_indices;
    }
    
    InitBuffer();
}

void gs_index_buffer::InitBuffer()
{
    NSUInteger         length  = len;
    MTLResourceOptions options = MTLResourceCPUCacheModeWriteCombined |
    MTLResourceStorageModeShared;
    
    metalIndexBuffer = [device->metalDevice newBufferWithBytes:&indices
                                                        length:length options:options];
    if (metalIndexBuffer == nil)
        throw "Failed to create index buffer";
    
#ifdef _DEBUG
    metalIndexBuffer.label = @"index";
#endif
}

void gs_index_buffer::Rebuild()
{
   if (!isDynamic)
       InitBuffer();
}
