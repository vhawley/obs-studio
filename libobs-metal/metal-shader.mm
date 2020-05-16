#include "metal-subsystem.hpp"

/** Start gs_shader functions
*/

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
