float4x4 gmWorldViewProj;
float4x4 gmWorld;
float4 gvPaintColor = float4(1,1,1,1);
float gfSpecularFactor = 0;
texture2D gtNoise;
texture2D gtDiffuse;
texture2D gtNormals;
texture2D gtSpecular;
sampler2D gsNoise = sampler_state
{
   Texture = <gtNoise>;
	MinFilter = POINT;  
    MagFilter = POINT;
    MipFilter = None;
    AddressU  = Wrap;
    AddressV  = Wrap;
};
sampler2D gsDiffuse = sampler_state
{
   Texture = <gtDiffuse>;
	MinFilter = ANISOTROPIC;  
    MagFilter = ANISOTROPIC;
    MipFilter = ANISOTROPIC;
    AddressU  = Wrap;
    AddressV  = Wrap;
};
sampler2D gsNormals = sampler_state
{
   Texture = <gtNormals>;
	MinFilter = ANISOTROPIC;  
    MagFilter = ANISOTROPIC;
    MipFilter = ANISOTROPIC;
    AddressU  = Wrap;
    AddressV  = Wrap;
};
sampler2D gsSpecular = sampler_state
{
   Texture = <gtSpecular>;
	MinFilter = ANISOTROPIC;  
    MagFilter = ANISOTROPIC;
    MipFilter = ANISOTROPIC;
    AddressU  = Wrap;
    AddressV  = Wrap;
};

struct VS_OUTPUT
{
    float4 vpos     : POSITION;
    float3 texcoord : TEXCOORD0;
    float3 normal   : TEXCOORD1;
    float3 tangent  : TEXCOORD2;
	float3 binormal : TEXCOORD3;
	float3 wpos		: TEXCOORD4;
};

struct VS_SHADOW_OUTPUT
{
    float4 vpos     : POSITION;
	float depth 	: TEXCOORD1;
	float2 texcoord : TEXCOORD0;
};

struct VS_INPUT
{
    float4 pos      : POSITION;
    float2 texcoord : TEXCOORD0;
    float3 normal   : NORMAL;
	float3 tangent  : TANGENT;
};

struct Deferred_OUT
{
    float4 col0      : COLOR0;
    float4 col1 	 : COLOR1;
	float4 col2 	 : COLOR2;
	//float4 col3 	 : COLOR3;
};

VS_OUTPUT DeferredVS(VS_INPUT IN)
{
    VS_OUTPUT OUT;
    float3 wpos = mul(gmWorld, IN.pos).xyz;
    OUT.vpos=mul(gmWorldViewProj,float4(IN.pos.xyz,1.0));
    OUT.normal = mul(gmWorld, IN.normal.xyz);
    OUT.texcoord.xy = IN.texcoord.xy;
	OUT.texcoord.z = OUT.vpos.z;
	OUT.tangent = mul(gmWorld, IN.tangent.xyz);
	OUT.binormal = mul(gmWorld,cross(IN.tangent,IN.normal));
	OUT.wpos =wpos;
    return OUT;
}

VS_SHADOW_OUTPUT shadowVS(VS_INPUT IN)
{
    VS_SHADOW_OUTPUT OUT;
    OUT.vpos=mul(gmWorldViewProj, float4(IN.pos.xyz,1.0));
	OUT.depth = mul(gmWorldViewProj, float4(IN.pos.xyz,1.0)).z;
	OUT.texcoord = IN.texcoord;
    return OUT;
}



float4 shadowPS(VS_SHADOW_OUTPUT IN) : COLOR
{
	float4 texColor = tex2D(gsDiffuse, IN.texcoord);
	clip(texColor.a);
	return float4(IN.depth,0,0,texColor.a);
}
float2 EncodeViewNormalStereo( float3 n )
{
	float kScale = 1.7777;
	float2 enc;
	enc = n.xy / (n.z+1);
	enc /= kScale;
	enc = enc*0.5+0.5;
	return enc;
}
float2 fInverseViewportDimensions = {1.0/1024.0,1.0/768.0};
Deferred_OUT DeferredPS(VS_OUTPUT IN,float2 viewpos:VPOS)
{
	Deferred_OUT OUT;
	float3 vNormal = (tex2D( gsNormals, IN.texcoord.xy ));
	vNormal.z = 1;
	vNormal = 2 * vNormal - 1.0;
	float3x3 mTangentToWorld = transpose( float3x3( IN.tangent, IN.binormal, IN.normal ) );
	float3   vNormalWorld    = normalize( mul( mTangentToWorld, vNormal ));
	float2 tc = viewpos*fInverseViewportDimensions + fInverseViewportDimensions*0.5f;
	OUT.col0 = tex2D(gsDiffuse, IN.texcoord.xy)* gvPaintColor;
	OUT.col1.xyz = vNormalWorld.xyz;
	float spec = (tex2D( gsSpecular, IN.texcoord.xy ).x>0)? tex2D( gsSpecular, IN.texcoord.xy ).x*gfSpecularFactor : gfSpecularFactor;
	OUT.col1.w = spec;
	OUT.col2 = float4(IN.wpos.xyz,IN.texcoord.z);
	//OUT.col0.w = (OUT.col0.w<0.6f)? 0.0f:OUT.col0.w;
	float clipingAlpha = 1-tex2D(gsNoise,1024.0f*tc/64.0f).x;
	OUT.col0.w = (OUT.col0.w<0.99f&&OUT.col0.w>0.01f)? clipingAlpha*OUT.col0.w:OUT.col0.w;
	clip(OUT.col0.w);
	//OUT.col3 = float4(1,1,1,1);
	return OUT;
}

technique Deferred
{
    pass p0
    {
        VertexShader = compile vs_3_0 DeferredVS();
        PixelShader  = compile ps_3_0 DeferredPS();
		AlphaTestEnable = true;
		AlphaBlendEnable = false;
    }
};
technique Shadow
{
    pass p0
    {
        VertexShader = compile vs_2_0 shadowVS();
        PixelShader  = compile ps_2_0 shadowPS();
		AlphaTestEnable = true;
		AlphaBlendEnable = false;
    }
};