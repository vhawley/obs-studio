#include "metal-subsystem.hpp"
#include "metal-shaderprocessor.hpp"

/** Start gs_shader functions
 */

static MTLCompileOptions *metalCompileOptions = nil;

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
    
    viewProjection = gs_shader_get_param_by_name(this, "ViewProj");
    world = gs_shader_get_param_by_name(this, "World");
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
    if (metalCompileOptions == nil) {
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
    if (lib == nil) {
        blog(LOG_DEBUG, "Converted shader program:\n%s\n------\n",
             metalShader.c_str());
        
        if (errors != nil)
            throw ShaderError(errors);
        else
            throw "Failed to compile shader";
    }
    
    id<MTLFunction> func = [lib newFunctionWithName:@"_main"];
    if (func == nil)
        throw "Failed to create function";
    
    metalLibrary  = lib;
    metalFunction = func;
}

void gs_shader_destroy(gs_shader_t *shader)
{
    
}

int gs_shader_get_num_params(const gs_shader_t *shader)
{
    
}

gs_sparam_t *gs_shader_get_param_by_idx(gs_shader_t *shader,
                                        uint32_t param)
{
    
}

gs_sparam_t *gs_shader_get_param_by_name(gs_shader_t *shader,
                                         const char *name)
{
    
}

gs_sparam_t *gs_shader_get_viewproj_matrix(const gs_shader_t *shader)
{
    
}

gs_sparam_t *gs_shader_get_world_matrix(const gs_shader_t *shader)
{
    
}

void gs_shader_get_param_info(const gs_sparam_t *param,
                              struct gs_shader_param_info *info)
{
    
}

void gs_shader_set_bool(gs_sparam_t *param, bool val)
{
    
}

void gs_shader_set_float(gs_sparam_t *param, float val)
{
    
}

void gs_shader_set_int(gs_sparam_t *param, int val)
{
    
}

void gs_shader_set_matrix3(gs_sparam_t *param,
                           const struct matrix3 *val)
{
    
}

void gs_shader_set_matrix4(gs_sparam_t *param,
                           const struct matrix4 *val)
{
    
}

void gs_shader_set_vec2(gs_sparam_t *param, const struct vec2 *val)
{
    
}

void gs_shader_set_vec3(gs_sparam_t *param, const struct vec3 *val)
{
    
}

void gs_shader_set_vec4(gs_sparam_t *param, const struct vec4 *val)
{
    
}

void gs_shader_set_texture(gs_sparam_t *param, gs_texture_t *val)
{
    
}

void gs_shader_set_val(gs_sparam_t *param, const void *val, size_t size)
{
    
}

void gs_shader_set_default(gs_sparam_t *param)
{
    
}

void gs_shader_set_next_sampler(gs_sparam_t *param,
                                gs_samplerstate_t *sampler)
{
    
}
