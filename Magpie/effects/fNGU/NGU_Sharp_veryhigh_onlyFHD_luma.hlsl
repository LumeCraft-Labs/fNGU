// ver. 0.1.0


//!MAGPIE EFFECT
//!VERSION 4
//!CAPABILITY FP16

//!PARAMETER
//!LABEL transfer
//!DEFAULT 0
//!MIN 0
//!MAX 3
//!STEP 1
int colorMode;

//!TEXTURE
Texture2D INPUT;

//!TEXTURE
//!WIDTH INPUT_WIDTH * 2
//!HEIGHT INPUT_HEIGHT * 2
Texture2D OUTPUT;

//!TEXTURE
//!SOURCE ngu_luma_1920x1080_veryhigh_2x_cubici1_constants.dds
//!FORMAT R32G32B32A32_FLOAT
Texture2D lumaInitialConstants;

//!TEXTURE
//!SOURCE ngu_luma_1920x1080_veryhigh_2x_layer_constants.dds
//!FORMAT R32G32B32A32_FLOAT
Texture2D lumaLayerConstants;

//!TEXTURE
//!SOURCE ngu_luma_1920x1080_veryhigh_2x_dense_constants.dds
//!FORMAT R32G32B32A32_FLOAT
Texture2D lumaDenseConstants;

//!TEXTURE
//!SOURCE ngu_luma_1920x1080_veryhigh_2x_scale_x_constants.dds
//!FORMAT R32G32B32A32_FLOAT
Texture2D lumaScaleXConstants;

//!TEXTURE
//!SOURCE ngu_luma_1920x1080_veryhigh_2x_scale_y_constants.dds
//!FORMAT R32G32B32A32_FLOAT
Texture2D lumaScaleYConstants;

//!TEXTURE
//!SOURCE ngu_luma_1920x1080_veryhigh_2x_add_constants.dds
//!FORMAT R32G32B32A32_FLOAT
Texture2D lumaAddConstants;


//!TEXTURE
//!WIDTH INPUT_WIDTH
//!HEIGHT INPUT_HEIGHT
//!FORMAT R16G16B16A16_FLOAT
Texture2D featureA0;

//!TEXTURE
//!WIDTH INPUT_WIDTH
//!HEIGHT INPUT_HEIGHT
//!FORMAT R16G16B16A16_FLOAT
Texture2D featureA1;

//!TEXTURE
//!WIDTH INPUT_WIDTH
//!HEIGHT INPUT_HEIGHT
//!FORMAT R16G16B16A16_FLOAT
Texture2D featureA2;

//!TEXTURE
//!WIDTH INPUT_WIDTH
//!HEIGHT INPUT_HEIGHT
//!FORMAT R16G16B16A16_FLOAT
Texture2D featureB0;

//!TEXTURE
//!WIDTH INPUT_WIDTH
//!HEIGHT INPUT_HEIGHT
//!FORMAT R16G16B16A16_FLOAT
Texture2D featureB1;

//!TEXTURE
//!WIDTH INPUT_WIDTH
//!HEIGHT INPUT_HEIGHT
//!FORMAT R16G16B16A16_FLOAT
Texture2D featureB2;

//!TEXTURE
//!WIDTH INPUT_WIDTH + 2
//!HEIGHT INPUT_HEIGHT + 2
//!FORMAT R16G16B16A16_FLOAT
Texture2D denseResidual;

//!TEXTURE
//!WIDTH INPUT_WIDTH * 2
//!HEIGHT INPUT_HEIGHT
//!FORMAT R16_UNORM
Texture2D lumaScaleX;

//!TEXTURE
//!WIDTH INPUT_WIDTH * 2
//!HEIGHT INPUT_HEIGHT * 2
//!FORMAT R16_UNORM
Texture2D lumaScaleY;

//!SAMPLER
//!FILTER POINT
SamplerState samPoint;

//!SAMPLER
//!FILTER LINEAR
SamplerState samLinear;

//!COMMON

bool IsSupportedInput() {
	return GetInputSize().x == 1920u && GetInputSize().y == 1080u &&
		colorMode >= 0 && colorMode <= 3;
}

float3 DecodeSrgb(float3 value) {
	const float3 result = value <= float3(0.04045, 0.04045, 0.04045) ?
		value / 12.92 :
		pow(
			max((value + 0.055) / 1.055, 0.0),
			float3(2.4, 2.4, 2.4));
	return result;
}

float3 EncodeSrgb(float3 value) {
	const float3 result = value <= float3(0.0031308, 0.0031308, 0.0031308) ?
		value * 12.92 :
		1.055 * pow(
			max(value, 0.0),
			float3(1.0 / 2.4, 1.0 / 2.4, 1.0 / 2.4)) - 0.055;
	return result;
}

float3 DecodeBt1886(float3 value) {
	return pow(
		max((value + 0.099) / 1.099, 0.0),
		float3(2.4, 2.4, 2.4));
}

float3 EncodeBt1886(float3 value) {
	return 1.099 * pow(
		max(value, 0.0),
		float3(1.0 / 2.4, 1.0 / 2.4, 1.0 / 2.4)) - 0.099;
}

float3 DecodeBt709(float3 value) {
	return value < float3(0.081, 0.081, 0.081) ?
		value / 4.5 :
		pow(
			max((value + 0.099) / 1.099, 0.0),
			float3(1.0 / 0.45, 1.0 / 0.45, 1.0 / 0.45));
}

float3 EncodeBt709(float3 value) {
	return value < float3(0.018, 0.018, 0.018) ?
		value * 4.5 :
		1.099 * pow(
			max(value, 0.0),
			float3(0.45, 0.45, 0.45)) - 0.099;
}

float3 DecodeLinearRgb(float3 value) {
	if (colorMode == 0) {
		return DecodeSrgb(value);
	}
	if (colorMode == 1) {
		return DecodeBt1886(value);
	}
	return DecodeBt709(value);
}

float3 EncodeLinearRgb(float3 value) {
	if (colorMode == 0) {
		return EncodeSrgb(value);
	}
	if (colorMode == 1) {
		return EncodeBt1886(value);
	}
	return EncodeBt709(value);
}

float EncodeLinearScalar(float value) {
	return EncodeLinearRgb(float3(value, value, value)).x;
}

float DecodeLinearScalar(float value) {
	return DecodeLinearRgb(float3(value, value, value)).x;
}

float RgbToNguLuma(float3 rgb) {
	if (colorMode == 3) {
		return dot(float3(0.299, 0.587, 0.114), rgb);
	}
	const float linearY = dot(float3(0.2126, 0.7152, 0.0722), DecodeLinearRgb(rgb));
	return EncodeLinearScalar(linearY);
}

float QuantizeR16(float value) {
	return floor(saturate(value) * 65535.0 + 0.5) / 65535.0;
}

float3 ReplaceLegacyLuma(float3 rgb, float luma) {
	const float2x3 rgb2uv = {
		-0.169, -0.331, 0.5,
		0.5, -0.419, -0.081
	};
	const float3x3 yuv2rgb = {
		1, -0.00093, 1.401687,
		1, -0.3437, -0.71417,
		1, 1.77216, 0.00099
	};
	const float2 uv = mul(rgb2uv, rgb);
	return mul(yuv2rgb, float3(luma, uv));
}

float3 ReplaceModernLuma(float3 originalLinear, float luma) {
	const float oldLuma =
		dot(float3(0.2126, 0.7152, 0.0722), originalLinear);
	const float newLuma = DecodeLinearScalar(luma);
	return EncodeLinearRgb(originalLinear + (newLuma - oldLuma));
}

//!PASS 1
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] initial 3-MRT
//!IN INPUT, lumaInitialConstants
//!OUT featureA0, featureA1, featureA2
//!BLOCK_SIZE 8
//!NUM_THREADS 64

groupshared float4 shInitialConstants[32];

float4 InitialConstant(int index) {
	return shInitialConstants[index];
}

MF4 InitialWeight(int index) {
	return MF4(InitialConstant(index));
}

MF4 FetchInitialLuma(float2 position) {
	uint2 size = GetInputSize();
	int2 pixel = int2(floor(position * float2(size)));
	pixel = clamp(pixel, int2(0, 0), int2(size) - 1);
	const MF4 rgb = INPUT.Load(int3(pixel, 0));
	const MF luma = MF(RgbToNguLuma(rgb.rgb));
	return MF4(luma, 0, 0, 1);
}

MF4 InitialLeakyReLU(MF4 value) {
	const MF slope = MF(InitialConstant(30).x);
	return max(value, 0) + min(value, 0) * slope;
}

void Pass1(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 32; i += 64) {
		shInitialConstants[i] = lumaInitialConstants.Load(int3(i, 0, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	const uint2 size = GetInputSize();
	if (!IsSupportedInput() || gxy.x >= size.x || gxy.y >= size.y) {
		return;
	}

	const float4 pt = InitialConstant(31);
	const float4 center = float4((float2(gxy) + 0.5f) * GetInputPt(), 0, 1);
	const MF4 s0 = FetchInitialLuma((center - pt).xy);
	const float4 offsets = float4(0, -1, 1, 0);

	const float4 positionA =
		pt.xyxy * offsets.xyzy + center.xyxy;
	const MF4 sampleA0 = FetchInitialLuma(positionA.xy);
	const MF4 sampleA1 = FetchInitialLuma(positionA.zw);

	const float4 positionB =
		pt.xyxy * offsets.yxzx + center.xyxy;
	const MF4 sampleB0 = FetchInitialLuma(positionB.xy);
	const MF4 sampleB1 = FetchInitialLuma(positionB.zw);
	const MF4 centerSample = FetchInitialLuma(center.xy);

	const float4 positionC =
		pt.xyxy * offsets.yzxz + center.xyxy;
	const MF4 sampleC0 = FetchInitialLuma(positionC.xy);
	const MF4 sampleC1 = FetchInitialLuma(positionC.zw);

	const float4 offsetD = pt.xxyw + center.xxyw;
	const MF4 diagonal = FetchInitialLuma(offsetD.yz);

	MF4 feature0 = mad(s0.x, InitialWeight(0), InitialWeight(27));
	feature0 = mad(sampleA0.x, InitialWeight(1), feature0);
	feature0 = mad(sampleA1.x, InitialWeight(2), feature0);
	feature0 = mad(sampleB0.x, InitialWeight(3), feature0);
	feature0 = mad(centerSample.x, InitialWeight(4), feature0);
	feature0 = mad(sampleB1.x, InitialWeight(5), feature0);
	feature0 = mad(sampleC0.x, InitialWeight(6), feature0);
	feature0 = mad(sampleC1.x, InitialWeight(7), feature0);
	feature0 = mad(diagonal.x, InitialWeight(8), feature0);

	MF4 feature1 = mad(s0.x, InitialWeight(9), InitialWeight(28));
	feature1 = mad(sampleA0.x, InitialWeight(10), feature1);
	feature1 = mad(sampleA1.x, InitialWeight(11), feature1);
	feature1 = mad(sampleB0.x, InitialWeight(12), feature1);
	feature1 = mad(centerSample.x, InitialWeight(13), feature1);
	feature1 = mad(sampleB1.x, InitialWeight(14), feature1);
	feature1 = mad(sampleC0.x, InitialWeight(15), feature1);
	feature1 = mad(sampleC1.x, InitialWeight(16), feature1);
	feature1 = mad(diagonal.x, InitialWeight(17), feature1);

	MF4 feature2 = mad(s0.x, InitialWeight(18), InitialWeight(29));
	feature2 = mad(sampleA0.x, InitialWeight(19), feature2);
	feature2 = mad(sampleA1.x, InitialWeight(20), feature2);
	feature2 = mad(sampleB0.x, InitialWeight(21), feature2);
	feature2 = mad(centerSample.x, InitialWeight(22), feature2);
	feature2 = mad(sampleB1.x, InitialWeight(23), feature2);
	feature2 = mad(sampleC0.x, InitialWeight(24), feature2);
	feature2 = mad(sampleC1.x, InitialWeight(25), feature2);
	feature2 = mad(diagonal.x, InitialWeight(26), feature2);

	featureA0[gxy] = InitialLeakyReLU(feature0);
	featureA1[gxy] = InitialLeakyReLU(feature1);
	featureA2[gxy] = InitialLeakyReLU(feature2);
}

//!PASS 2
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] hidden layer 0 3-MRT
//!IN featureA0, featureA1, featureA2, lumaLayerConstants
//!OUT featureB0, featureB1, featureB2
//!BLOCK_SIZE 8
//!NUM_THREADS 64

#define LAYER_INPUT0 featureA0
#define LAYER_INPUT1 featureA1
#define LAYER_INPUT2 featureA2

groupshared float4 shLayerConstants[333];

float4 LayerConstant(int index, int row) {
	return shLayerConstants[(row - 0) * 111 + index];
}

MF4 LayerWeight(int index, int row) {
	return MF4(LayerConstant(index, row));
}

MF4 FetchLayer0(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT0.Load(int3(pixel, 0));
}

MF4 FetchLayer1(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT1.Load(int3(pixel, 0));
}

MF4 FetchLayer2(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT2.Load(int3(pixel, 0));
}

MF4 LayerGroup0(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer0(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup1(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer1(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup2(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer2(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerSampleGroup(
	float2 position, int base, int row, int2 dimensions
) {
	const MF4 a = LayerGroup0(position, base, row, dimensions);
	const MF4 b = LayerGroup1(position, base + 36, row, dimensions);
	const MF4 c = LayerGroup2(position, base + 72, row, dimensions);
	return c + (a + b);
}

MF4 EvaluateLayer(float2 center, int row, int2 dimensions) {
	const float2 pixelPoint = LayerConstant(110, row).xy;
	MF4 value =
		LayerSampleGroup(center - pixelPoint, 0, row, dimensions) +
		LayerWeight(108, row);

	const float4 positions0 =
		pixelPoint.xyxy * float4(0, -1, 1, -1) + center.xyxy;
	value += LayerSampleGroup(positions0.xy, 4, row, dimensions);
	value += LayerSampleGroup(positions0.zw, 8, row, dimensions);

	const float4 positions1 =
		pixelPoint.xyxy * float4(-1, 0, 1, 0) + center.xyxy;
	value += LayerSampleGroup(positions1.xy, 12, row, dimensions);
	value += LayerSampleGroup(center, 16, row, dimensions);
	value += LayerSampleGroup(positions1.zw, 20, row, dimensions);

	const float4 positions2 =
		pixelPoint.xyxy * float4(-1, 1, 0, 1) + center.xyxy;
	value += LayerSampleGroup(positions2.xy, 24, row, dimensions);
	value += LayerSampleGroup(positions2.zw, 28, row, dimensions);
	value += LayerSampleGroup(center + pixelPoint, 32, row, dimensions);

	const MF slope = MF(LayerConstant(109, row).x);
	return max(value, 0) + min(value, 0) * slope;
}

void Pass2(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 333; i += 64) {
		const uint row = i / 111;
		const uint index = i - row * 111;
		shLayerConstants[i] =
			lumaLayerConstants.Load(int3(index, row + 0, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	const uint2 inputSize = GetInputSize();
	if (!IsSupportedInput() || gxy.x >= inputSize.x || gxy.y >= inputSize.y) {
		return;
	}

	const float2 center = (float2(gxy) + 0.5f) * GetInputPt();
	const int2 dimensions = int2(inputSize);
	featureB0[gxy] = EvaluateLayer(center, 0, dimensions);
	featureB1[gxy] = EvaluateLayer(center, 1, dimensions);
	featureB2[gxy] = EvaluateLayer(center, 2, dimensions);
}

#undef LAYER_INPUT0
#undef LAYER_INPUT1
#undef LAYER_INPUT2

//!PASS 3
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] hidden layer 1 3-MRT
//!IN featureB0, featureB1, featureB2, lumaLayerConstants
//!OUT featureA0, featureA1, featureA2
//!BLOCK_SIZE 8
//!NUM_THREADS 64

#define LAYER_INPUT0 featureB0
#define LAYER_INPUT1 featureB1
#define LAYER_INPUT2 featureB2

groupshared float4 shLayerConstants[333];

float4 LayerConstant(int index, int row) {
	return shLayerConstants[(row - 3) * 111 + index];
}

MF4 LayerWeight(int index, int row) {
	return MF4(LayerConstant(index, row));
}

MF4 FetchLayer0(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT0.Load(int3(pixel, 0));
}

MF4 FetchLayer1(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT1.Load(int3(pixel, 0));
}

MF4 FetchLayer2(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT2.Load(int3(pixel, 0));
}

MF4 LayerGroup0(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer0(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup1(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer1(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup2(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer2(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerSampleGroup(
	float2 position, int base, int row, int2 dimensions
) {
	const MF4 a = LayerGroup0(position, base, row, dimensions);
	const MF4 b = LayerGroup1(position, base + 36, row, dimensions);
	const MF4 c = LayerGroup2(position, base + 72, row, dimensions);
	return c + (a + b);
}

MF4 EvaluateLayer(float2 center, int row, int2 dimensions) {
	const float2 pixelPoint = LayerConstant(110, row).xy;
	MF4 value =
		LayerSampleGroup(center - pixelPoint, 0, row, dimensions) +
		LayerWeight(108, row);

	const float4 positions0 =
		pixelPoint.xyxy * float4(0, -1, 1, -1) + center.xyxy;
	value += LayerSampleGroup(positions0.xy, 4, row, dimensions);
	value += LayerSampleGroup(positions0.zw, 8, row, dimensions);

	const float4 positions1 =
		pixelPoint.xyxy * float4(-1, 0, 1, 0) + center.xyxy;
	value += LayerSampleGroup(positions1.xy, 12, row, dimensions);
	value += LayerSampleGroup(center, 16, row, dimensions);
	value += LayerSampleGroup(positions1.zw, 20, row, dimensions);

	const float4 positions2 =
		pixelPoint.xyxy * float4(-1, 1, 0, 1) + center.xyxy;
	value += LayerSampleGroup(positions2.xy, 24, row, dimensions);
	value += LayerSampleGroup(positions2.zw, 28, row, dimensions);
	value += LayerSampleGroup(center + pixelPoint, 32, row, dimensions);

	const MF slope = MF(LayerConstant(109, row).x);
	return max(value, 0) + min(value, 0) * slope;
}

void Pass3(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 333; i += 64) {
		const uint row = i / 111;
		const uint index = i - row * 111;
		shLayerConstants[i] =
			lumaLayerConstants.Load(int3(index, row + 3, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	const uint2 inputSize = GetInputSize();
	if (!IsSupportedInput() || gxy.x >= inputSize.x || gxy.y >= inputSize.y) {
		return;
	}

	const float2 center = (float2(gxy) + 0.5f) * GetInputPt();
	const int2 dimensions = int2(inputSize);
	featureA0[gxy] = EvaluateLayer(center, 3, dimensions);
	featureA1[gxy] = EvaluateLayer(center, 4, dimensions);
	featureA2[gxy] = EvaluateLayer(center, 5, dimensions);
}

#undef LAYER_INPUT0
#undef LAYER_INPUT1
#undef LAYER_INPUT2

//!PASS 4
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] hidden layer 2 3-MRT
//!IN featureA0, featureA1, featureA2, lumaLayerConstants
//!OUT featureB0, featureB1, featureB2
//!BLOCK_SIZE 8
//!NUM_THREADS 64

#define LAYER_INPUT0 featureA0
#define LAYER_INPUT1 featureA1
#define LAYER_INPUT2 featureA2

groupshared float4 shLayerConstants[333];

float4 LayerConstant(int index, int row) {
	return shLayerConstants[(row - 6) * 111 + index];
}

MF4 LayerWeight(int index, int row) {
	return MF4(LayerConstant(index, row));
}

MF4 FetchLayer0(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT0.Load(int3(pixel, 0));
}

MF4 FetchLayer1(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT1.Load(int3(pixel, 0));
}

MF4 FetchLayer2(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT2.Load(int3(pixel, 0));
}

MF4 LayerGroup0(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer0(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup1(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer1(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup2(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer2(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerSampleGroup(
	float2 position, int base, int row, int2 dimensions
) {
	const MF4 a = LayerGroup0(position, base, row, dimensions);
	const MF4 b = LayerGroup1(position, base + 36, row, dimensions);
	const MF4 c = LayerGroup2(position, base + 72, row, dimensions);
	return c + (a + b);
}

MF4 EvaluateLayer(float2 center, int row, int2 dimensions) {
	const float2 pixelPoint = LayerConstant(110, row).xy;
	MF4 value =
		LayerSampleGroup(center - pixelPoint, 0, row, dimensions) +
		LayerWeight(108, row);

	const float4 positions0 =
		pixelPoint.xyxy * float4(0, -1, 1, -1) + center.xyxy;
	value += LayerSampleGroup(positions0.xy, 4, row, dimensions);
	value += LayerSampleGroup(positions0.zw, 8, row, dimensions);

	const float4 positions1 =
		pixelPoint.xyxy * float4(-1, 0, 1, 0) + center.xyxy;
	value += LayerSampleGroup(positions1.xy, 12, row, dimensions);
	value += LayerSampleGroup(center, 16, row, dimensions);
	value += LayerSampleGroup(positions1.zw, 20, row, dimensions);

	const float4 positions2 =
		pixelPoint.xyxy * float4(-1, 1, 0, 1) + center.xyxy;
	value += LayerSampleGroup(positions2.xy, 24, row, dimensions);
	value += LayerSampleGroup(positions2.zw, 28, row, dimensions);
	value += LayerSampleGroup(center + pixelPoint, 32, row, dimensions);

	const MF slope = MF(LayerConstant(109, row).x);
	return max(value, 0) + min(value, 0) * slope;
}

void Pass4(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 333; i += 64) {
		const uint row = i / 111;
		const uint index = i - row * 111;
		shLayerConstants[i] =
			lumaLayerConstants.Load(int3(index, row + 6, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	const uint2 inputSize = GetInputSize();
	if (!IsSupportedInput() || gxy.x >= inputSize.x || gxy.y >= inputSize.y) {
		return;
	}

	const float2 center = (float2(gxy) + 0.5f) * GetInputPt();
	const int2 dimensions = int2(inputSize);
	featureB0[gxy] = EvaluateLayer(center, 6, dimensions);
	featureB1[gxy] = EvaluateLayer(center, 7, dimensions);
	featureB2[gxy] = EvaluateLayer(center, 8, dimensions);
}

#undef LAYER_INPUT0
#undef LAYER_INPUT1
#undef LAYER_INPUT2

//!PASS 5
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] hidden layer 3 3-MRT
//!IN featureB0, featureB1, featureB2, lumaLayerConstants
//!OUT featureA0, featureA1, featureA2
//!BLOCK_SIZE 8
//!NUM_THREADS 64

#define LAYER_INPUT0 featureB0
#define LAYER_INPUT1 featureB1
#define LAYER_INPUT2 featureB2

groupshared float4 shLayerConstants[333];

float4 LayerConstant(int index, int row) {
	return shLayerConstants[(row - 9) * 111 + index];
}

MF4 LayerWeight(int index, int row) {
	return MF4(LayerConstant(index, row));
}

MF4 FetchLayer0(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT0.Load(int3(pixel, 0));
}

MF4 FetchLayer1(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT1.Load(int3(pixel, 0));
}

MF4 FetchLayer2(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT2.Load(int3(pixel, 0));
}

MF4 LayerGroup0(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer0(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup1(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer1(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup2(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer2(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerSampleGroup(
	float2 position, int base, int row, int2 dimensions
) {
	const MF4 a = LayerGroup0(position, base, row, dimensions);
	const MF4 b = LayerGroup1(position, base + 36, row, dimensions);
	const MF4 c = LayerGroup2(position, base + 72, row, dimensions);
	return c + (a + b);
}

MF4 EvaluateLayer(float2 center, int row, int2 dimensions) {
	const float2 pixelPoint = LayerConstant(110, row).xy;
	MF4 value =
		LayerSampleGroup(center - pixelPoint, 0, row, dimensions) +
		LayerWeight(108, row);

	const float4 positions0 =
		pixelPoint.xyxy * float4(0, -1, 1, -1) + center.xyxy;
	value += LayerSampleGroup(positions0.xy, 4, row, dimensions);
	value += LayerSampleGroup(positions0.zw, 8, row, dimensions);

	const float4 positions1 =
		pixelPoint.xyxy * float4(-1, 0, 1, 0) + center.xyxy;
	value += LayerSampleGroup(positions1.xy, 12, row, dimensions);
	value += LayerSampleGroup(center, 16, row, dimensions);
	value += LayerSampleGroup(positions1.zw, 20, row, dimensions);

	const float4 positions2 =
		pixelPoint.xyxy * float4(-1, 1, 0, 1) + center.xyxy;
	value += LayerSampleGroup(positions2.xy, 24, row, dimensions);
	value += LayerSampleGroup(positions2.zw, 28, row, dimensions);
	value += LayerSampleGroup(center + pixelPoint, 32, row, dimensions);

	const MF slope = MF(LayerConstant(109, row).x);
	return max(value, 0) + min(value, 0) * slope;
}

void Pass5(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 333; i += 64) {
		const uint row = i / 111;
		const uint index = i - row * 111;
		shLayerConstants[i] =
			lumaLayerConstants.Load(int3(index, row + 9, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	const uint2 inputSize = GetInputSize();
	if (!IsSupportedInput() || gxy.x >= inputSize.x || gxy.y >= inputSize.y) {
		return;
	}

	const float2 center = (float2(gxy) + 0.5f) * GetInputPt();
	const int2 dimensions = int2(inputSize);
	featureA0[gxy] = EvaluateLayer(center, 9, dimensions);
	featureA1[gxy] = EvaluateLayer(center, 10, dimensions);
	featureA2[gxy] = EvaluateLayer(center, 11, dimensions);
}

#undef LAYER_INPUT0
#undef LAYER_INPUT1
#undef LAYER_INPUT2

//!PASS 6
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] hidden layer 4 3-MRT
//!IN featureA0, featureA1, featureA2, lumaLayerConstants
//!OUT featureB0, featureB1, featureB2
//!BLOCK_SIZE 8
//!NUM_THREADS 64

#define LAYER_INPUT0 featureA0
#define LAYER_INPUT1 featureA1
#define LAYER_INPUT2 featureA2

groupshared float4 shLayerConstants[333];

float4 LayerConstant(int index, int row) {
	return shLayerConstants[(row - 12) * 111 + index];
}

MF4 LayerWeight(int index, int row) {
	return MF4(LayerConstant(index, row));
}

MF4 FetchLayer0(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT0.Load(int3(pixel, 0));
}

MF4 FetchLayer1(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT1.Load(int3(pixel, 0));
}

MF4 FetchLayer2(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return LAYER_INPUT2.Load(int3(pixel, 0));
}

MF4 LayerGroup0(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer0(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup1(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer1(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerGroup2(float2 position, int base, int row, int2 dimensions) {
	const MF4 sample = FetchLayer2(position, dimensions);
#ifdef MP_FP16
	MF4 value = sample.y * LayerWeight(base + 1, row);
#else
	precise MF4 value = sample.y * LayerWeight(base + 1, row);
#endif
	value = mad(sample.x, LayerWeight(base, row), value);
	value = mad(sample.z, LayerWeight(base + 2, row), value);
	value = mad(sample.w, LayerWeight(base + 3, row), value);
	return value;
}

MF4 LayerSampleGroup(
	float2 position, int base, int row, int2 dimensions
) {
	const MF4 a = LayerGroup0(position, base, row, dimensions);
	const MF4 b = LayerGroup1(position, base + 36, row, dimensions);
	const MF4 c = LayerGroup2(position, base + 72, row, dimensions);
	return c + (a + b);
}

MF4 EvaluateLayer(float2 center, int row, int2 dimensions) {
	const float2 pixelPoint = LayerConstant(110, row).xy;
	MF4 value =
		LayerSampleGroup(center - pixelPoint, 0, row, dimensions) +
		LayerWeight(108, row);

	const float4 positions0 =
		pixelPoint.xyxy * float4(0, -1, 1, -1) + center.xyxy;
	value += LayerSampleGroup(positions0.xy, 4, row, dimensions);
	value += LayerSampleGroup(positions0.zw, 8, row, dimensions);

	const float4 positions1 =
		pixelPoint.xyxy * float4(-1, 0, 1, 0) + center.xyxy;
	value += LayerSampleGroup(positions1.xy, 12, row, dimensions);
	value += LayerSampleGroup(center, 16, row, dimensions);
	value += LayerSampleGroup(positions1.zw, 20, row, dimensions);

	const float4 positions2 =
		pixelPoint.xyxy * float4(-1, 1, 0, 1) + center.xyxy;
	value += LayerSampleGroup(positions2.xy, 24, row, dimensions);
	value += LayerSampleGroup(positions2.zw, 28, row, dimensions);
	value += LayerSampleGroup(center + pixelPoint, 32, row, dimensions);

	const MF slope = MF(LayerConstant(109, row).x);
	return max(value, 0) + min(value, 0) * slope;
}

void Pass6(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 333; i += 64) {
		const uint row = i / 111;
		const uint index = i - row * 111;
		shLayerConstants[i] =
			lumaLayerConstants.Load(int3(index, row + 12, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	const uint2 inputSize = GetInputSize();
	if (!IsSupportedInput() || gxy.x >= inputSize.x || gxy.y >= inputSize.y) {
		return;
	}

	const float2 center = (float2(gxy) + 0.5f) * GetInputPt();
	const int2 dimensions = int2(inputSize);
	featureB0[gxy] = EvaluateLayer(center, 12, dimensions);
	featureB1[gxy] = EvaluateLayer(center, 13, dimensions);
	featureB2[gxy] = EvaluateLayer(center, 14, dimensions);
}

#undef LAYER_INPUT0
#undef LAYER_INPUT1
#undef LAYER_INPUT2

//!PASS 7
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] dense residual 1922x1082
//!IN featureB0, featureB1, featureB2, lumaDenseConstants
//!OUT denseResidual
//!BLOCK_SIZE 8
//!NUM_THREADS 64

#define Feature0 featureB0
#define Feature1 featureB1
#define Feature2 featureB2

groupshared float4 shDenseConstants[51];

float4 DenseConstant(int index) {
	return shDenseConstants[index];
}

float4 Fetch0(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return Feature0.Load(int3(pixel, 0));
}

float4 Fetch1(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return Feature1.Load(int3(pixel, 0));
}

float4 Fetch2(float2 position, int2 dimensions) {
	int2 pixel = int2(floor(position * float2(dimensions)));
	pixel = clamp(pixel, int2(0, 0), dimensions - 1);
	return Feature2.Load(int3(pixel, 0));
}

void Pass7(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 51; i += 64) {
		shDenseConstants[i] = lumaDenseConstants.Load(int3(i, 0, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	if (!IsSupportedInput() || gxy.x >= 1922u || gxy.y >= 1082u) {
		return;
	}

	int width, height; Feature0.GetDimensions(width, height); const int2 featureDimensions = int2(width, height); float4 v0 = float4((float2(gxy) + 0.5f) / DenseConstant(50).xy, 0.0, 1.0);float4 DL51 = float4(-1,1,0,0);
	  float4 r0_init = float4(0,0,0,0);
	  float4 r1_init = float4(0,0,0,0);
	  float4 r2_init = float4(0,0,0,0);
	  float4 r3_init = float4(0,0,0,0);
	  float4 r4_init = float4(0,0,0,0);
	  float4 r5_init = float4(0,0,0,0);
	  float4 r6_init = float4(0,0,0,0);
	  float4 r7_init = float4(0,0,0,0);
	  float4 r8_init = float4(0,0,0,0);
	  float4 r9_init = float4(0,0,0,0);
	  float4 r10_init = float4(0,0,0,0);
	  float4 r11_init = float4(0,0,0,0);
	  float4 r12_init = float4(0,0,0,0);
	  float4 r13_init = float4(0,0,0,0);
	  float4 r14_init = float4(0,0,0,0);
	  float4 r15_init = float4(0,0,0,0);
	  float4 r16_init = float4(0,0,0,0);
	  float4 r17_init = float4(0,0,0,0);
	  float4 r18_init = float4(0,0,0,0);
	  float4 r19_init = float4(0,0,0,0);
	  float4 r20_init = float4(0,0,0,0);
	  float4 r21_init = float4(0,0,0,0);
	  float4 r22_init = float4(0,0,0,0);
	  float4 r23_init = float4(0,0,0,0);
	  float4 r24_init = float4(0,0,0,0);
	  float4 r25_init = float4(0,0,0,0);
	  float4 r26_init = float4(0,0,0,0);
	  float4 r27_init = float4(0,0,0,0);
	  float4 r28_init = float4(0,0,0,0);
	  float4 r29_init = float4(0,0,0,0);
	  float4 r30_init = float4(0,0,0,0);
	  float4 r31_init = float4(0,0,0,0);
	  float4 e1 = DL51;
	  float4 w1 = float4(e1.x, e1.y, e1.z, r0_init.w);
	  float4 e2 = (v0.xyzy * DenseConstant(50).xyzy + w1.xxxx);
	  float4 w2 = float4(e2.x, w1.y, w1.z, e2.w);
	  float4 e3 = (w2.xwzw * DenseConstant(49));
	  float4 w3 = float4(e3.x, e3.y, r1_init.z, r1_init.w);
	  float4 e4 = (w2 * DenseConstant(49).xyzy + DenseConstant(49).xyzy);
	  float4 w4 = float4(e4.x, w2.y, w2.z, e4.w);
	  float4 w5 = Fetch0(w3, featureDimensions);
	  float4 e6 = dot(w5, DenseConstant(10));
	  float4 w6 = float4(w3.x, w3.y, e6.z, w3.w);
	  float4 w7 = Fetch1(w6, featureDimensions);
	  float4 e8 = dot(w7, DenseConstant(26));
	  float4 w8 = float4(w6.x, w6.y, w6.z, e8.w);
	  float4 e9 = (w8.wwww + w8.zzzz);
	  float4 w9 = float4(w8.x, w8.y, e9.z, w8.w);
	  float4 w10 = Fetch2(w9, featureDimensions);
	  float4 w11 = (DenseConstant(49).xyxy * w4.yzzy + w9.xyxy);
	  float4 e12 = dot(w10, DenseConstant(42));
	  float4 w12 = float4(w4.x, e12.y, w4.z, w4.w);
	  float4 e13 = (w12.yyyy + w9.zzzz);
	  float4 w13 = float4(w12.x, e13.y, w12.z, w12.w);
	  float4 w14 = Fetch0(w11, featureDimensions);
	  float4 e15 = dot(w14, DenseConstant(8));
	  float4 w15 = float4(w13.x, w13.y, e15.z, w13.w);
	  float4 e16 = (w15.zzzz + w15.yyyy);
	  float4 w16 = float4(w15.x, e16.y, w15.z, w15.w);
	  float4 w17 = Fetch1(w11, featureDimensions);
	  float4 e18 = dot(w17, DenseConstant(24));
	  float4 w18 = float4(w16.x, w16.y, e18.z, w16.w);
	  float4 e19 = (w18.zzzz + w18.yyyy);
	  float4 w19 = float4(w18.x, e19.y, w18.z, w18.w);
	  float4 w20 = Fetch2(w11, featureDimensions);
	  float4 e21 = dot(w20, DenseConstant(40));
	  float4 w21 = float4(w19.x, w19.y, e21.z, w19.w);
	  float4 e22 = (w21.zzzz + w21.yyyy);
	  float4 w22 = float4(w21.x, e22.y, w21.z, w21.w);
	  float4 w23 = Fetch0(w11.zwzw, featureDimensions);
	  float4 e24 = dot(w23, DenseConstant(2));
	  float4 w24 = float4(w22.x, w22.y, e24.z, w22.w);
	  float4 e25 = (w24.zzzz + w24.yyyy);
	  float4 w25 = float4(w24.x, e25.y, w24.z, w24.w);
	  float4 w26 = Fetch1(w11.zwzw, featureDimensions);
	  float4 w27 = Fetch2(w11.zwzw, featureDimensions);
	  float4 e28 = dot(w26, DenseConstant(18));
	  float4 w28 = float4(w25.x, w25.y, e28.z, w25.w);
	  float4 e29 = (w28.zzzz + w28.yyyy);
	  float4 w29 = float4(w28.x, e29.y, w28.z, w28.w);
	  float4 e30 = dot(w27, DenseConstant(34));
	  float4 w30 = float4(w29.x, w29.y, e30.z, w29.w);
	  float4 e31 = (w30.zzzz + w30.yyyy);
	  float4 w31 = float4(w30.x, e31.y, w30.z, w30.w);
	  float4 w32 = Fetch0(w31.xwzw, featureDimensions);
	  float4 e33 = dot(w32, DenseConstant(0));
	  float4 w33 = float4(w31.x, w31.y, e33.z, w31.w);
	  float4 e34 = (w33.zzzz + w33.yyyy);
	  float4 w34 = float4(w33.x, e34.y, w33.z, w33.w);
	  float4 w35 = Fetch1(w34.xwzw, featureDimensions);
	  float4 w36 = Fetch2(w34.xwzw, featureDimensions);
	  float4 e37 = dot(w35, DenseConstant(16));
	  float4 w37 = float4(e37.x, w34.y, w34.z, w34.w);
	  float4 e38 = (w37.xxxx + w37.yyyy);
	  float4 w38 = float4(e38.x, w37.y, w37.z, w37.w);
	  float4 e39 = dot(w36, DenseConstant(32));
	  float4 w39 = float4(w38.x, e39.y, w38.z, w38.w);
	  float4 e40 = (w39.yyyy + w39.xxxx);
	  float4 w40 = float4(e40.x, w39.y, w39.z, w39.w);
	  float4 e41 = dot(w14, DenseConstant(9));
	  float4 w41 = float4(e41.x, r13_init.y, r13_init.z, r13_init.w);
	  float4 e42 = dot(w5, DenseConstant(11));
	  float4 w42 = float4(w41.x, e42.y, w41.z, w41.w);
	  float4 e43 = dot(w7, DenseConstant(27));
	  float4 w43 = float4(w42.x, w42.y, e43.z, w42.w);
	  float4 e44 = (w43.zzzz + w43.yyyy);
	  float4 w44 = float4(w43.x, e44.y, w43.z, w43.w);
	  float4 e45 = dot(w10, DenseConstant(43));
	  float4 w45 = float4(w44.x, w44.y, e45.z, w44.w);
	  float4 e46 = (w45.zzzz + w45.yyyy);
	  float4 w46 = float4(w45.x, e46.y, w45.z, w45.w);
	  float4 e47 = (w46.xxxx + w46.yyyy);
	  float4 w47 = float4(e47.x, w46.y, w46.z, w46.w);
	  float4 e48 = dot(w17, DenseConstant(25));
	  float4 w48 = float4(w47.x, e48.y, w47.z, w47.w);
	  float4 e49 = (w48.yyyy + w48.xxxx);
	  float4 w49 = float4(e49.x, w48.y, w48.z, w48.w);
	  float4 e50 = dot(w20, DenseConstant(41));
	  float4 w50 = float4(w49.x, e50.y, w49.z, w49.w);
	  float4 e51 = (w50.yyyy + w50.xxxx);
	  float4 w51 = float4(e51.x, w50.y, w50.z, w50.w);
	  float4 e52 = dot(w23, DenseConstant(3));
	  float4 w52 = float4(w51.x, e52.y, w51.z, w51.w);
	  float4 e53 = (w52.yyyy + w52.xxxx);
	  float4 w53 = float4(e53.x, w52.y, w52.z, w52.w);
	  float4 e54 = dot(w26, DenseConstant(19));
	  float4 w54 = float4(w53.x, e54.y, w53.z, w53.w);
	  float4 e55 = (w54.yyyy + w54.xxxx);
	  float4 w55 = float4(e55.x, w54.y, w54.z, w54.w);
	  float4 e56 = dot(w27, DenseConstant(35));
	  float4 w56 = float4(w55.x, e56.y, w55.z, w55.w);
	  float4 e57 = (w56.yyyy + w56.xxxx);
	  float4 w57 = float4(e57.x, w56.y, w56.z, w56.w);
	  float4 e58 = dot(w32, DenseConstant(1));
	  float4 w58 = float4(w57.x, e58.y, w57.z, w57.w);
	  float4 e59 = (w58.yyyy + w58.xxxx);
	  float4 w59 = float4(e59.x, w58.y, w58.z, w58.w);
	  float4 e60 = dot(w35, DenseConstant(17));
	  float4 w60 = float4(w59.x, e60.y, w59.z, w59.w);
	  float4 e61 = (w60.yyyy + w60.xxxx);
	  float4 w61 = float4(e61.x, w60.y, w60.z, w60.w);
	  float4 e62 = dot(w36, DenseConstant(33));
	  float4 w62 = float4(w61.x, e62.y, w61.z, w61.w);
	  float4 e63 = (w62.yyyy + w62.xxxx);
	  float4 w63 = float4(w40.x, e63.y, w40.z, w40.w);
	  float4 e64 = dot(w5, DenseConstant(14));
	  float4 w64 = float4(e64.x, w62.y, w62.z, w62.w);
	  float4 e65 = dot(w5, DenseConstant(15));
	  float4 w65 = float4(e65.x, w5.y, w5.z, w5.w);
	  float4 e66 = dot(w7, DenseConstant(30));
	  float4 w66 = float4(w65.x, e66.y, w65.z, w65.w);
	  float4 e67 = dot(w7, DenseConstant(31));
	  float4 w67 = float4(w66.x, w66.y, e67.z, w66.w);
	  float4 e68 = (w67.zzzz + w67.xxxx);
	  float4 w68 = float4(e68.x, w67.y, w67.z, w67.w);
	  float4 e69 = (w68.yyyy + w64.xxxx);
	  float4 w69 = float4(w68.x, e69.y, w68.z, w68.w);
	  float4 e70 = dot(w10, DenseConstant(46));
	  float4 w70 = float4(w69.x, w69.y, e70.z, w69.w);
	  float4 e71 = dot(w10, DenseConstant(47));
	  float4 w71 = float4(w70.x, w70.y, w70.z, e71.w);
	  float4 e72 = (w71.wzzw + w71);
	  float4 w72 = float4(e72.x, e72.y, w71.z, w71.w);
	  float4 e73 = dot(w14, DenseConstant(12));
	  float4 w73 = float4(w72.x, w72.y, e73.z, w72.w);
	  float4 e74 = dot(w14, DenseConstant(13));
	  float4 w74 = float4(e74.x, w14.y, w14.z, w14.w);
	  float4 e75 = (w74.xxxx + w73.xxxx);
	  float4 w75 = float4(e75.x, w74.y, w74.z, w74.w);
	  float4 e76 = (w73.zzzz + w73.yyyy);
	  float4 w76 = float4(w75.x, e76.y, w75.z, w75.w);
	  float4 e77 = dot(w17, DenseConstant(28));
	  float4 w77 = float4(w76.x, w76.y, e77.z, w76.w);
	  float4 e78 = dot(w17, DenseConstant(29));
	  float4 w78 = float4(w77.x, w77.y, w77.z, e78.w);
	  float4 e79 = (w78.wzzw + w78);
	  float4 w79 = float4(e79.x, e79.y, w78.z, w78.w);
	  float4 e80 = dot(w20, DenseConstant(44));
	  float4 w80 = float4(w79.x, w79.y, e80.z, w79.w);
	  float4 e81 = dot(w20, DenseConstant(45));
	  float4 w81 = float4(w80.x, w80.y, w80.z, e81.w);
	  float4 e82 = (w81.wzzw + w81);
	  float4 w82 = float4(e82.x, e82.y, w81.z, w81.w);
	  float4 e83 = dot(w23, DenseConstant(6));
	  float4 w83 = float4(w82.x, w82.y, e83.z, w82.w);
	  float4 e84 = dot(w23, DenseConstant(7));
	  float4 w84 = float4(w83.x, w83.y, w83.z, e84.w);
	  float4 e85 = (w84.wzzw + w84);
	  float4 w85 = float4(e85.x, e85.y, w84.z, w84.w);
	  float4 e86 = dot(w26, DenseConstant(22));
	  float4 w86 = float4(w85.x, w85.y, e86.z, w85.w);
	  float4 e87 = dot(w26, DenseConstant(23));
	  float4 w87 = float4(w86.x, w86.y, w86.z, e87.w);
	  float4 e88 = (w87.wzzw + w87);
	  float4 w88 = float4(e88.x, e88.y, w87.z, w87.w);
	  float4 e89 = dot(w27, DenseConstant(38));
	  float4 w89 = float4(w88.x, w88.y, e89.z, w88.w);
	  float4 e90 = dot(w27, DenseConstant(39));
	  float4 w90 = float4(w89.x, w89.y, w89.z, e90.w);
	  float4 e91 = (w90.wzzw + w90);
	  float4 w91 = float4(e91.x, e91.y, w90.z, w90.w);
	  float4 e92 = dot(w32, DenseConstant(4));
	  float4 w92 = float4(w91.x, w91.y, e92.z, w91.w);
	  float4 e93 = dot(w32, DenseConstant(5));
	  float4 w93 = float4(w92.x, w92.y, w92.z, e93.w);
	  float4 e94 = (w93.wzzw + w93);
	  float4 w94 = float4(e94.x, e94.y, w93.z, w93.w);
	  float4 e95 = dot(w35, DenseConstant(20));
	  float4 w95 = float4(w94.x, w94.y, e95.z, w94.w);
	  float4 e96 = dot(w35, DenseConstant(21));
	  float4 w96 = float4(w95.x, w95.y, w95.z, e96.w);
	  float4 e97 = (w96.wzzw + w96);
	  float4 w97 = float4(e97.x, e97.y, w96.z, w96.w);
	  float4 e98 = dot(w36, DenseConstant(36));
	  float4 w98 = float4(w97.x, w97.y, e98.z, w97.w);
	  float4 e99 = dot(w36, DenseConstant(37));
	  float4 w99 = float4(w98.x, w98.y, w98.z, e99.w);
	  float4 e100 = (w99 + w99.xyyx);
	  float4 w100 = float4(w63.x, w63.y, e100.z, e100.w);
	  float4 w101 = (w100 + DenseConstant(48).xxxx);
	  denseResidual[gxy] = w101;
}

#undef Feature0
#undef Feature1
#undef Feature2

//!PASS 8
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] source Luma 2x X
//!IN INPUT, lumaScaleXConstants
//!OUT lumaScaleX
//!BLOCK_SIZE 8
//!NUM_THREADS 64

groupshared float4 shScaleXConstants[2];

float4 ScaleXConstant(int index) {
	return shScaleXConstants[index];
}

float FetchSourceLumaX(float2 position) {
	const uint2 size = GetInputSize();
	int2 pixel = int2(floor(position * float2(size)));
	pixel = clamp(pixel, int2(0, 0), int2(size) - 1);
	const float4 rgb = INPUT.Load(int3(pixel, 0));
	return RgbToNguLuma(rgb.rgb);
}

void Pass8(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 2; i += 64) {
		shScaleXConstants[i] = lumaScaleXConstants.Load(int3(i, 0, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	if (!IsSupportedInput() || gxy.x >= 3840u || gxy.y >= 1080u) {
		return;
	}

	const float4 scale = ScaleXConstant(0);
	const float4 weightsSource = ScaleXConstant(1);
	const float2 uv = (float2(gxy) + 0.5f) / float2(3840, 1080);
	const float scaled = scale.x * uv.x - 2.0;
	const float fraction = frac(scaled);
	const float negative = (-fraction >= 0.0) ? 1.0 : 0.0;
	const float whole = scaled - fraction;
	const float base = (scaled >= 0.0) ? 0.0 : negative;
	const float integerPosition = base + whole;
	const float position =
		(frac(integerPosition * 0.5) - 0.349999994 >= 0.0) ?
		integerPosition :
		integerPosition - 2.0;
	const float4 weights =
		(frac(integerPosition * 0.5) - 0.349999994 >= 0.0) ?
		weightsSource.zxyw :
		weightsSource.wyxz;
	const float coordinate0 = position * scale.y;
	const float coordinate1 = coordinate0 + scale.z;
	const float coordinate2 = coordinate1 + scale.z;
	const float coordinate3 = coordinate2 + scale.z;

	float result =
		FetchSourceLumaX(float2(coordinate0, uv.y)) * weights.x +
		FetchSourceLumaX(float2(coordinate1, uv.y)) * weights.y;
	result =
		FetchSourceLumaX(float2(coordinate2, uv.y)) * weights.z + result;
	result =
		FetchSourceLumaX(float2(coordinate3, uv.y)) * weights.w + result;
	lumaScaleX[gxy] = QuantizeR16(result);
}

//!PASS 9
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] source Luma 2x Y
//!IN lumaScaleX, lumaScaleYConstants
//!OUT lumaScaleY
//!BLOCK_SIZE 8
//!NUM_THREADS 64

groupshared float4 shScaleYConstants[2];

float4 ScaleYConstant(int index) {
	return shScaleYConstants[index];
}

float FetchSourceLumaY(float outputX, int sourceY) {
	int2 pixel = int2(int(floor(outputX * 3840.0)), sourceY);
	pixel = clamp(pixel, int2(0, 0), int2(3839, 1079));
	return lumaScaleX.Load(int3(pixel, 0));
}

void Pass9(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 2; i += 64) {
		shScaleYConstants[i] = lumaScaleYConstants.Load(int3(i, 0, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	if (!IsSupportedInput() || gxy.x >= 3840u || gxy.y >= 2160u) {
		return;
	}

	const float4 scale = ScaleYConstant(0);
	const float4 weightsSource = ScaleYConstant(1);
	const float2 uv = (float2(gxy) + 0.5f) * GetOutputPt();
	const float scaled = scale.x * uv.y - 2.0;
	const float fraction = frac(scaled);
	const float negative = (-fraction >= 0.0) ? 1.0 : 0.0;
	const float whole = scaled - fraction;
	const float base = (scaled >= 0.0) ? 0.0 : negative;
	const float integerPosition = base + whole;
	const float position =
		(frac(integerPosition * 0.5) - 0.349999994 >= 0.0) ?
		integerPosition :
		integerPosition - 2.0;
	const float4 weights =
		(frac(integerPosition * 0.5) - 0.349999994 >= 0.0) ?
		weightsSource.zxyw :
		weightsSource.wyxz;
	const int firstSource = int(floor(position * 0.5));

	float result =
		FetchSourceLumaY(uv.x, firstSource) * weights.x +
		FetchSourceLumaY(uv.x, firstSource + 1) * weights.y;
	result =
		FetchSourceLumaY(uv.x, firstSource + 2) * weights.z + result;
	result =
		FetchSourceLumaY(uv.x, firstSource + 3) * weights.w + result;
	lumaScaleY[gxy] = QuantizeR16(result);
}

//!PASS 10
//!DESC [NGU_Sharp_veryhigh_onlyFHD_luma] dense add and RGB reconstruction
//!IN INPUT, lumaScaleY, denseResidual, lumaAddConstants
//!OUT OUTPUT
//!BLOCK_SIZE 8
//!NUM_THREADS 64

groupshared float4 shAddConstants[2];

float4 AddConstant(int index) {
	return shAddConstants[index];
}

float4 FetchDense(float2 position) {
	int2 pixel = int2(floor(position * float2(1922, 1082)));
	pixel = clamp(pixel, int2(0, 0), int2(1921, 1081));
	return denseResidual.Load(int3(pixel, 0));
}

float3 SampleInputLinearLight(float2 position) {
	const float2 sourcePosition = position * float2(1920, 1080) - 0.5;
	const int2 base = int2(floor(sourcePosition));
	const float2 fraction = frac(sourcePosition);
	const int2 size = int2(1919, 1079);
	const int2 p00 = clamp(base, int2(0, 0), size);
	const int2 p10 = clamp(base + int2(1, 0), int2(0, 0), size);
	const int2 p01 = clamp(base + int2(0, 1), int2(0, 0), size);
	const int2 p11 = clamp(base + int2(1, 1), int2(0, 0), size);
	const float3 c00 = DecodeLinearRgb(INPUT.Load(int3(p00, 0)).rgb);
	const float3 c10 = DecodeLinearRgb(INPUT.Load(int3(p10, 0)).rgb);
	const float3 c01 = DecodeLinearRgb(INPUT.Load(int3(p01, 0)).rgb);
	const float3 c11 = DecodeLinearRgb(INPUT.Load(int3(p11, 0)).rgb);
	return lerp(lerp(c00, c10, fraction.x), lerp(c01, c11, fraction.x), fraction.y);
}

void Pass10(uint2 blockStart, uint3 threadId) {
	for (uint i = threadId.x; i < 2; i += 64) {
		shAddConstants[i] = lumaAddConstants.Load(int3(i, 0, 0));
	}
	GroupMemoryBarrierWithGroupSync();

	const uint2 gxy = blockStart + Rmp8x8(threadId.x);
	const uint2 outputSize = GetOutputSize();
	if (gxy.x >= outputSize.x || gxy.y >= outputSize.y) {
		return;
	}
	if (!IsSupportedInput()) {
		OUTPUT[gxy] = float4(0, 0, 0, 1);
		return;
	}

	const float2 outputPosition = (float2(gxy) + 0.5f) * GetOutputPt();
	const float4 inverseDenseSize = AddConstant(0);
	const float4 sourceSize = AddConstant(1);
	const float2 densePixel =
		floor(outputPosition * sourceSize.xy + 0.5) + 0.5;
	const float2 densePosition = densePixel * inverseDenseSize.xy;
	const float4 residual = FetchDense(densePosition);
	const float2 phase = frac(outputPosition * sourceSize.xy) - 0.5;
	float correction;
	if (phase.y < 0.0) {
		correction = phase.x < 0.0 ? residual.w : residual.z;
	} else {
		correction = phase.x < 0.0 ? residual.y : residual.x;
	}

	const float base = lumaScaleY.Load(int3(gxy, 0));
	const float luma = QuantizeR16(base + correction);

	float3 rgb;
	if (colorMode == 3) {
		const float3 sourceRgb =
			INPUT.SampleLevel(samLinear, outputPosition, 0).rgb;
		rgb = ReplaceLegacyLuma(sourceRgb, luma);
	} else {
		const float3 originalLinear = SampleInputLinearLight(outputPosition);
		rgb = ReplaceModernLuma(originalLinear, luma);
	}
	OUTPUT[gxy] = float4(saturate(rgb), 1);
}

