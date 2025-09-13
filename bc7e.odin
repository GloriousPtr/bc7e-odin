package bc7e

import "core:c"

foreign import bc7e "bc7e.lib"

/*
-- API

The C-style API is modeled after ispc_texcomp's and is very simple. Note that
(just like with ispc_texcomp) you must do all multithreading on your own - BC7E
just encodes blocks on a single thread using SIMD instructions.

First, before doing anything with BC7E, call compress_block_init() a
single time (and preferably only a single time). This proc computes some
lookup tables used to accelerate encoding. If you fail to call this proc, the
encoder will always return all-zero BC7 block data. (This is different from
ispc_texcomp.)

Next, call one of these procs in the BC7E ispc code to select the encoding
profile you want to use:

compress_block_params_init_ultrafast(struct compress_block_params * p, bool perceptual) (mode 6 only for non-alpha blocks)
compress_block_params_init_veryfast()
compress_block_params_init_fast() 
compress_block_params_init_basic() (a good default profile)
compress_block_params_init_slow()

The fastest mode is ultrafast on opaque blocks, which selects an optimized code path that only supports mode 6.

Note these procs are calibrated to compete against ispc_texcomp's similarly
named profiles. The "slow" profile is significantly faster than ispc_texcomp's
(by around 8x). Also, unlike ispc_texcomp BC7E automatically determines if each
block has any pixels using alpha, so there's no need to select an alpha specific profile.

These two profiles are slower than "slow", but have higher quality, and are still faster than ispc_texcomp's "slow" profile:
compress_block_params_init_slowest()
compress_block_params_init_veryslow()

It's possible to customize the codec yourself by tweaking one of these basic profiles.

Each of these init procs takes a pointer to an encoding params struct
(compress_block_params), and a bool "perceptual" parameter. If you
know the source pixels will be in sRGB space, enabling perceptual mode will
noticeably improve the Y PSNR/SSIM, possibly allowing you to use a faster
encoding profile.

These init procs are all thread safe: they just fill in the params struct you provide with internal codec settings.

Finally, call compress_blocks() with an array of 4x4 pixel blocks. You should
always call this proc with a multiple of 8-16 blocks. Try to call it with at
least 32-64 blocks. Note that this proc wants a pointer to an array of 16
pixel blocks, one block after the other, which is slightly different from
ispc_texcomp's input. This proc is thread safe.

If you call this proc without calling compress_block_init() first, the
encoder will return blocks filled with all 0's (or assert() if you build the
ispc file in debug).

-- Optional support for encoding textures with decorrelated alpha channels

BC7's is weakest with textures containing decorrelated alpha channels. This can
lead to noticeable blockiness in either RGB or A with every encoder we've tried.
By default, the encoder doesn't do anything special vs. other encoders to handle
this scenario. It normally optimizes for lowest overall RGBA error, which can
cause the encoder to select correlated alpha modes that cause either RGB or A to
appear overly blocky (but still leading to overall lowest error).

We've added an optional mode 6/7 specific error metric weighting vector, which
allows you to nudge the encoder to use the correlated alpha modes less often.

To use this feature, after you call one of the profile selection procs
(compress_block_params_init_basic() etc.), you can optionally set the
values in the "m_alpha_settings.m_mode67_error_weight_mul[]" array. 

This array contains a per-component error weight multiplier that's
only used in modes 6/7. This allows you to deemphasize the usage of the
correlated alpha modes (6/7). These modes can cause blockiness in either RGB or
A on highly uncorrelated textures containing complex alpha channels. To use
this, I would first start with setting the RGB (first 3 array values) to 3,3,3
or 5,5,5 and test the results. 

Setting these values higher than 1 will cause the encoder to use modes 4/5 more
often on alpha blocks. This will result in higher overall PSNR/SSIM error, but
hopefully less blockiness.
*/

opaque_settings :: struct {
	m_max_mode13_partitions_to_try: c.uint32_t,
	m_max_mode0_partitions_to_try:  c.uint32_t,
	m_max_mode2_partitions_to_try:  c.uint32_t,
	m_use_mode:                     [7]c.bool,
	m_unused1:                      c.bool,
}

alpha_settings :: struct {
	m_max_mode7_partitions_to_try: c.uint32_t,
	m_mode67_error_weight_mul:     [4]c.uint32_t,
	m_use_mode4:                   c.bool,
	m_use_mode5:                   c.bool,
	m_use_mode6:                   c.bool,
	m_use_mode7:                   c.bool,
	m_use_mode4_rotation:          c.bool,
	m_use_mode5_rotation:          c.bool,
	m_unused2:                     c.bool,
	m_unused3:                     c.bool,
}

compress_block_params :: struct {
	m_max_partitions_mode:   [8]c.uint32_t,
	m_weights:               [4]c.uint32_t,
	m_uber_level:            c.uint32_t,
	m_refinement_passes:     c.uint32_t,
	m_mode4_rotation_mask:   c.uint32_t,
	m_mode4_index_mask:      c.uint32_t,
	m_mode5_rotation_mask:   c.uint32_t,
	m_uber1_mask:            c.uint32_t,
	m_perceptual:            c.bool,
	m_pbit_search:           c.bool,
	m_mode6_only:            c.bool,
	m_unused0:               c.bool,
	m_opaque_settings:       opaque_settings,
	m_alpha_settings:        alpha_settings,
}

@(default_calling_convention = "c", link_prefix="bc7e_")
foreign bc7e {
	/*
	Call once (and preferably only a single time). This proc computes some lookup tables used to accelerate encoding.
	If you fail to call this proc, the encoder will always return all-zero BC7 block data.
	*/
	compress_block_init :: proc() ---

	compress_block_params_init           :: proc(p: ^compress_block_params, perceptual: b8) ---
	compress_block_params_init_basic     :: proc(p: ^compress_block_params, perceptual: b8) ---
	compress_block_params_init_fast      :: proc(p: ^compress_block_params, perceptual: b8) ---
	compress_block_params_init_slow      :: proc(p: ^compress_block_params, perceptual: b8) ---
	compress_block_params_init_slowest   :: proc(p: ^compress_block_params, perceptual: b8) ---
	compress_block_params_init_ultrafast :: proc(p: ^compress_block_params, perceptual: b8) ---
	compress_block_params_init_veryfast  :: proc(p: ^compress_block_params, perceptual: b8) ---
	compress_block_params_init_veryslow  :: proc(p: ^compress_block_params, perceptual: b8) ---

	/*
	Call with an array of 4x4 pixel blocks.	You should always call this proc with a multiple of 8-16 blocks.
	Try to call it with at least 32-64 blocks. Note that this proc wants a pointer to an array of 16 pixel blocks, one block after the other.
	*/
	compress_blocks :: proc(num_blocks: u32, pBlocks: [^]c.uint64_t, pPixelsRGBA: [^]c.uint32_t, pComp_params: ^compress_block_params) ---
}
