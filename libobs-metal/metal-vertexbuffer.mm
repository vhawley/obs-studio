#include <util/base.h>
#include <graphics/vec3.h>

 #include "metal-subsystem.hpp"

 using namespace std;

 gs_vertex_buffer::gs_vertex_buffer(gs_device_t *device, struct gs_vb_data *data,
       uint32_t flags)
   : gs_object    (device, GS_VERTEX_BUFFER),
     isDynamic ((flags & GS_DYNAMIC) != 0),
     vbData(data)
{
   if (!data->num)
       throw "Cannot initialize vertex buffer with 0 vertices";
   if (!data->points)
       throw "No points specified for vertex buffer";

   if (!isDynamic)
       InitBuffers();
}

 void gs_vertex_buffer::FlushBuffers(gs_vb_data *data)
{
   assert(isDynamic);
    
    size_t num_tex = data->num_tex < uvBuffers.size() ? data->num_tex : uvBuffers.size();
    
    if(vbData != nil && vbData != data) {
        gs_vbdata_destroy(vbData);
        vbData = data;
    }
    
    if (data->points)
        vertexBuffer = InitBuffer(sizeof(vec3), data->points, "point");

    if (normalBuffer && data->normals)
        normalBuffer = InitBuffer(sizeof(vec3), data->normals, "normal");

    if (tangentBuffer && data->tangents)
        tangentBuffer = InitBuffer(sizeof(vec3), data->tangents, "tangent");

    if (colorBuffer && data->colors)
        colorBuffer = InitBuffer(sizeof(uint32_t), data->colors, "color");

    for (size_t i = 0; i < num_tex; i++) {
        gs_tvertarray &tv = data->tvarray[i];
        uvBuffers[i] = InitBuffer(tv.width * sizeof(float), tv.array, "texcoord");
    }
}

 static inline void PushBuffer(vector<id<MTLBuffer>> &buffers,
       id<MTLBuffer> buffer, const char *name)
{
   if (buffer != nil) {
       buffers.push_back(buffer);
   } else {
       blog(LOG_ERROR, "This vertex shader requires a %s buffer",
               name);
   }
}

 void gs_vertex_buffer::MakeBufferList(gs_vertex_shader *shader,
       vector<id<MTLBuffer>> &buffers)
{
    if (isDynamic) {
        InitBuffers();
    }
   PushBuffer(buffers, vertexBuffer, "point");
   if (shader->hasNormals)
       PushBuffer(buffers, normalBuffer, "normal");
   if (shader->hasColors)
       PushBuffer(buffers, colorBuffer, "color");
   if (shader->hasTangents)
       PushBuffer(buffers, tangentBuffer, "tangent");
   if (shader->texUnits <= uvBuffers.size()) {
       for (size_t i = 0; i < shader->texUnits; i++)
           buffers.push_back(uvBuffers[i]);
   } else {
       blog(LOG_ERROR, "This vertex shader requires at least %u "
                       "texture buffers.",
                       (uint32_t)shader->texUnits);
   }
}

 inline id<MTLBuffer> gs_vertex_buffer::InitBuffer(size_t elementSize,
       void *array, const char *name)
{
   NSUInteger         length  = elementSize * vbData->num;
   MTLResourceOptions options = MTLResourceCPUCacheModeWriteCombined |
           (isDynamic ? MTLResourceStorageModeShared :
           MTLResourceStorageModeManaged);

   id<MTLBuffer> buffer = [device->metalDevice newBufferWithBytes:array
           length:length options:options];
   if (buffer == nil)
       throw "Failed to create buffer";

 #ifdef _DEBUG
   buffer.label = [[NSString alloc] initWithUTF8String:name];
#endif

   return buffer;
}

 void gs_vertex_buffer::InitBuffers()
{
   vertexBuffer = InitBuffer(sizeof(vec3), vbData->points, "point");
   if (vbData->normals)
       normalBuffer = InitBuffer(sizeof(vec3), vbData->normals,
               "normal");
   if (vbData->tangents)
       tangentBuffer = InitBuffer(sizeof(vec3), vbData->tangents,
               "tangents");
   if (vbData->colors)
       colorBuffer = InitBuffer(sizeof(uint32_t), vbData->colors,
               "colors");
    
    for (size_t i = 0; i < vbData->num_tex; i++) {
        struct gs_tvertarray *tverts = vbData->tvarray + i;

        if (tverts->width != 2 && tverts->width != 4)
            throw "Invalid texture vertex size specified";
        if (!tverts->array)
            throw "No texture vertices specified";

        id<MTLBuffer> buffer = InitBuffer(tverts->width * sizeof(float),
                tverts->array, "texcoord");
        uvBuffers.emplace_back(buffer);
    }
}

void gs_vertex_buffer::Rebuild()
{
   if (!isDynamic)
       InitBuffers();
}
