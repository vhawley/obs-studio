#include <graphics/vec2.h>
#include <graphics/vec3.h>
#include <graphics/matrix3.h>
#include <graphics/matrix4.h>

#include "metal-subsystem.hpp"
#include "metal-shaderprocessor.hpp"

/** Start gs_shader functions
 */

static MTLCompileOptions *metalCompileOptions = nullptr;

gs_shader::gs_shader(gs_device_t *device, const char *shader, const char *file, gs_shader_type shader_type)
: gs_object(device, GS_SHADER),
shader(shader),
file(file),
shaderType(shader_type)
{
    // Compile Metal shader
}

gs_pixel_shader::gs_pixel_shader(gs_device_t *device, const char *shader, const char *file)
: gs_shader(device, shader, file, GS_SHADER_PIXEL)
{
    ShaderProcessor processor(device);
    
    processor.Process(shader, file);
    metalShader = processor.BuildString(shaderType);
    processor.BuildParams(params);
    processor.BuildSamplers(samplers);
    BuildConstantBuffer();
    
    Compile();
}

gs_vertex_shader::gs_vertex_shader(gs_device_t *device, const char *shader, const char *file)
: gs_shader(device, shader, file, GS_SHADER_VERTEX)
{
    ShaderProcessor     processor(device);
    ShaderBufferInfo    info;
    MTLVertexDescriptor *vertdesc;
    
    vertdesc = [[MTLVertexDescriptor alloc] init];
    
    processor.Process(shader, file);
    metalShader = processor.BuildString(shaderType);
    processor.BuildParams(params);
    processor.BuildParamInfo(info);
    processor.BuildVertexDesc(vertdesc);
    BuildConstantBuffer();
    
    Compile();
    
    hasNormals  = info.normals;
    hasColors   = info.colors;
    hasTangents = info.tangents;
    texUnits    = info.texUnits;
    
    vertexDescriptor  = vertdesc;
    
    viewProjectionMatrix = gs_shader_get_param_by_name(this, "ViewProj");
    worldMatrix = gs_shader_get_param_by_name(this, "World");
}

void gs_shader::BuildConstantBuffer()
{
    for (size_t i = 0; i < params.size(); i++) {
        gs_shader_param &param = params[i];
        size_t          size   = 0;
        
        switch (param.type) {
            case GS_SHADER_PARAM_BOOL:
            case GS_SHADER_PARAM_INT:
            case GS_SHADER_PARAM_FLOAT:     size = sizeof(float);     break;
            case GS_SHADER_PARAM_INT2:
            case GS_SHADER_PARAM_VEC2:      size = sizeof(vec2);      break;
            case GS_SHADER_PARAM_INT3:
            case GS_SHADER_PARAM_VEC3:      size = sizeof(float) * 3; break;
            case GS_SHADER_PARAM_INT4:
            case GS_SHADER_PARAM_VEC4:      size = sizeof(vec4);      break;
            case GS_SHADER_PARAM_MATRIX4X4:
                size = sizeof(float) * 4 * 4;
                break;
            case GS_SHADER_PARAM_TEXTURE:
            case GS_SHADER_PARAM_STRING:
            case GS_SHADER_PARAM_UNKNOWN:
                continue;
        }
        
        /* checks to see if this constant needs to start at a new
         * register */
        if (size && (constantSize & 15) != 0) {
            size_t alignMax = (constantSize + 15) & ~15;
            
            if ((size + constantSize) > alignMax)
                constantSize = alignMax;
        }
        
        param.pos = constantSize;
        constantSize += size;
    }
    
    for (gs_shader_param &param : params)
        gs_shader_set_default(&param);
    
    data.resize(constantSize);
}

void gs_shader::Compile()
{
    if (metalCompileOptions == nullptr) {
        metalCompileOptions = [[MTLCompileOptions alloc] init];
        metalCompileOptions.languageVersion = MTLLanguageVersion2_2;
    }
    
    NSString *nsShaderString = [[NSString alloc]
                                initWithBytesNoCopy:(void*)metalShader.data()
                                length:metalShader.length()
                                encoding:NSUTF8StringEncoding freeWhenDone:NO];
    NSError *errors;
    id<MTLLibrary> lib = [device->metalDevice newLibraryWithSource:nsShaderString
                                                           options:metalCompileOptions error:&errors];
    [nsShaderString dealloc];
    
    if (lib == nullptr) {
        blog(LOG_DEBUG, "Converted shader program:\n%s\n------\n",
             metalShader.c_str());
        
        if (errors != nullptr)
            throw ShaderError(errors);
        else
            throw "Failed to compile shader";
    }
    
    id<MTLFunction> func = [lib newFunctionWithName:@"_main"];
    if (func == nullptr)
        throw "Failed to create function";
    
    metalLibrary  = lib;
    metalFunction = func;
}

inline void gs_shader::UpdateParam(uint8_t *data, gs_shader_param &param)
{
   if (param.type != GS_SHADER_PARAM_TEXTURE) {
       if (!param.curValue.size())
           throw "Not all shader parameters were set";

       if (param.changed) {
           memcpy(data + param.pos, param.curValue.data(),
                   param.curValue.size());
           param.changed = false;
       }

   } else if (param.curValue.size() == sizeof(gs_texture_t*)) {
       gs_texture_t *tex;
       memcpy(&tex, param.curValue.data(), sizeof(gs_texture_t*));
       device_load_texture(device, tex, param.textureID);

       if (param.nextSampler) {
           device_load_samplerstate(device, param.nextSampler,
                   param.textureID);
           param.nextSampler = nullptr;
       }
   }
}

void gs_shader::UploadParams(id<MTLRenderCommandEncoder> commandEncoder)
{
   uint8_t *ptr = data.data();

   for (size_t i = 0; i < params.size(); i++)
       UpdateParam(ptr, params[i]);

   if (!constantSize)
       return;

   id<MTLBuffer> cnt = device->GetBuffer(ptr, data.size());
#if _DEBUG
   cnt.label = @"constants";
#endif

   if (shaderType == GS_SHADER_VERTEX)
       [commandEncoder setVertexBuffer:cnt offset:0 atIndex:30];
   else if (shaderType == GS_SHADER_PIXEL)
       [commandEncoder setFragmentBuffer:cnt offset:0 atIndex:30];
   else
       throw "This is unknown shader type";
}

void gs_shader_destroy(gs_shader_t *shader)
{
    assert(shader != nullptr);
    assert(shader->objectType == GS_SHADER);
    
    if (shader->device->lastVertexShader == shader)
        shader->device->lastVertexShader = nullptr;
    
    delete shader;
}

int gs_shader_get_num_params(const gs_shader_t *shader)
{
    assert(shader != nullptr);
    assert(shader->objectType == GS_SHADER);

    return (int)shader->params.size();
}

gs_sparam_t *gs_shader_get_param_by_idx(gs_shader_t *shader,
                                        uint32_t param)
{
    assert(shader != nullptr);
    assert(shader->objectType == GS_SHADER);

    return &shader->params[param];
}

gs_sparam_t *gs_shader_get_param_by_name(gs_shader_t *shader,
                                         const char *name)
{
    assert(shader != nullptr);
    assert(shader->objectType == GS_SHADER);
    for (size_t i = 0; i < shader->params.size(); i++) {
         gs_shader_param &param = shader->params[i];
         if (strcmp(param.name.c_str(), name) == 0)
             return &param;
     }

      return nullptr;
}

gs_sparam_t *gs_shader_get_viewproj_matrix(const gs_shader_t *shader)
{
    assert(shader != nullptr);
    assert(shader->objectType == GS_SHADER);
    if (shader->shaderType != GS_SHADER_VERTEX)
         return nullptr;

    return static_cast<const gs_vertex_shader*>(shader)->viewProjectionMatrix;
}

gs_sparam_t *gs_shader_get_world_matrix(const gs_shader_t *shader)
{
    assert(shader != nullptr);
    assert(shader->objectType == GS_SHADER);
    if (shader->shaderType != GS_SHADER_VERTEX)
         return nullptr;
    
    return static_cast<const gs_vertex_shader*>(shader)->worldMatrix;
}

void gs_shader_get_param_info(const gs_sparam_t *param,
                              struct gs_shader_param_info *info)
{
    if (!param)
        return;
    
    info->name = param->name.c_str();
    info->type = param->type;
}

static inline void shader_setval_inline(gs_shader_param *param,
       const void *data, size_t size)
{
   assert(param);

   if (!param)
       return;

   bool size_changed = param->curValue.size() != size;
   if (size_changed)
       param->curValue.resize(size);

   if (size_changed || memcmp(param->curValue.data(), data, size) != 0) {
       memcpy(param->curValue.data(), data, size);
       param->changed = true;
   }
}

void gs_shader_set_bool(gs_sparam_t *param, bool val)
{
    int b_val = (int)val;
     shader_setval_inline(param, &b_val, sizeof(int));
}

void gs_shader_set_float(gs_sparam_t *param, float val)
{
    shader_setval_inline(param, &val, sizeof(float));
}

void gs_shader_set_int(gs_sparam_t *param, int val)
{
    shader_setval_inline(param, &val, sizeof(float));
}

void gs_shader_set_matrix3(gs_sparam_t *param,
                           const struct matrix3 *val)
{
    struct matrix4 mat;
    matrix4_from_matrix3(&mat, val);
    shader_setval_inline(param, &mat, sizeof(matrix4));
}

void gs_shader_set_matrix4(gs_sparam_t *param,
                           const struct matrix4 *val)
{
    shader_setval_inline(param, val, sizeof(matrix4));
}

void gs_shader_set_vec2(gs_sparam_t *param, const struct vec2 *val)
{
    shader_setval_inline(param, val, sizeof(vec2));
}

void gs_shader_set_vec3(gs_sparam_t *param, const struct vec3 *val)
{
    shader_setval_inline(param, val, sizeof(float) * 3);
}

void gs_shader_set_vec4(gs_sparam_t *param, const struct vec4 *val)
{
    shader_setval_inline(param, val, sizeof(vec4));
}

void gs_shader_set_texture(gs_sparam_t *param, gs_texture_t *val)
{
    shader_setval_inline(param, &val, sizeof(gs_texture_t*));
}

void gs_shader_set_val(gs_sparam_t *param, const void *val, size_t size)
{
    shader_setval_inline(param, val, size);
}

void gs_shader_set_default(gs_sparam_t *param)
{
    if (param->defaultValue.size())
    shader_setval_inline(param, param->defaultValue.data(),
            param->defaultValue.size());
}

void gs_shader_set_next_sampler(gs_sparam_t *param,
                                gs_samplerstate_t *sampler)
{
    param->nextSampler = sampler;
}
