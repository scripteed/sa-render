#include "CSkyRender.h"
#include "CGame.h"
#include "CDebug.h"

ID3DXEffect *CSkyRender::m_pEffect;
IDirect3DTexture9 *CSkyRender::CloudTex;
D3DXMATRIX CSkyRender::gm_WorldViewProjection;
D3DXMATRIX CSkyRender::gm_World;
LPD3DXMESH CSkyRender::skySphere;

bool CSkyRender::Setup()
{
	ID3DXBuffer *errors;
	HRESULT result = D3DXCreateEffectFromFile(g_Device,"sky.fx", 0, 0, 0, 0, &m_pEffect, &errors);
	if(!CDebug::CheckForD3D9Errors(errors,"CSkyRender::Setup: D3DXCreateEffectFromFile() - failed while compiling sky.fx",result))
	{
		return false;
	}
	D3DXCreateTextureFromFile(g_Device,"clouds.tga",&CloudTex);
	return true;
}
struct _VERTEX {
	D3DXVECTOR3 pos;     // vertex position
	D3DXVECTOR3 norm;    // vertex normal
	float tu;            // texture coordinates
	float tv;
} VERTEX,*LPVERTEX;

#define FVF_VERTEX    D3DFVF_XYZ|D3DFVF_NORMAL|D3DFVF_TEX1
bool CSkyRender::CreateSkySphere(float fRad,UINT slices,UINT stacks) {
	// create the sphere
	LPD3DXMESH mesh;
	if (FAILED(D3DXCreateSphere(g_Device,fRad,slices,stacks,&mesh,NULL)))
		return false;
	if (FAILED(mesh->CloneMeshFVF(D3DXMESH_SYSTEMMEM,FVF_VERTEX,g_Device,&skySphere)))
		return false;
	// finished with the original mesh, release it
	mesh->Release();
	// lock the vertex buffer
	_VERTEX* pVerts = NULL;
	if (SUCCEEDED(skySphere->LockVertexBuffer(0,(VOID **) &pVerts))) {
		// get vertex count
		int numVerts=skySphere->GetNumVertices();

		// loop through the vertices
		for (int i=0;i<numVerts;i++) {
			pVerts->tu=asinf(pVerts->norm.x)/D3DX_PI+0.5f;
			pVerts->tv=asinf(pVerts->norm.y)/D3DX_PI+0.5f;
			pVerts++;
		}
		// unlock the vertex buffer
		skySphere->UnlockVertexBuffer();
	}
	return true;
}
void CSkyRender::PreRender(D3DXVECTOR3 *pos,D3DXMATRIX *viewproj)
{
	CreateSkySphere(1000,100,100);
	D3DXMATRIX meshRotate, meshTranslate;
	D3DXMatrixRotationY(&meshRotate, D3DXToRadian(0));
	D3DXMatrixTranslation(&meshTranslate, pos->x,pos->y,pos->z);
	D3DXMatrixMultiply(&gm_World, &meshRotate, &meshTranslate);
	D3DXMatrixMultiplyTranspose(&gm_WorldViewProjection, &gm_World, viewproj);
}
void CSkyRender::Render(D3DXVECTOR4 *lightDirection)
{
	UINT passes;
	DWORD oDB,oSB,oBO,oAB,oAT;
	g_Device->GetRenderState(D3DRS_DESTBLEND,&oDB);
	g_Device->GetRenderState(D3DRS_SRCBLEND,&oSB);
	g_Device->GetRenderState(D3DRS_BLENDOP,&oBO);
	g_Device->GetRenderState(D3DRS_ALPHABLENDENABLE,&oAB);
	g_Device->GetRenderState(D3DRS_ALPHATESTENABLE,&oAT);
	m_pEffect->SetTechnique("Sky");
	m_pEffect->SetTexture("cloudTex",CloudTex);
	m_pEffect->SetVector("lightDirection",lightDirection);
	m_pEffect->SetMatrix("gmWorldViewProj",&gm_WorldViewProjection);
	m_pEffect->SetMatrix("gmWorld",&gm_World);
	m_pEffect->Begin(&passes,0);
	m_pEffect->BeginPass(0);
	skySphere->DrawSubset(0);
	m_pEffect->EndPass();
	m_pEffect->End();
	g_Device->SetRenderState(D3DRS_DESTBLEND,oDB);
	g_Device->SetRenderState(D3DRS_SRCBLEND,oSB);
	g_Device->SetRenderState(D3DRS_BLENDOP,oBO);
	g_Device->SetRenderState(D3DRS_ALPHABLENDENABLE,oAB);
	g_Device->SetRenderState(D3DRS_ALPHATESTENABLE,oAT);
}
void CSkyRender::Release()
{
	SAFE_RELEASE(skySphere);
}