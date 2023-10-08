using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Serialization;

public class RayManager : MonoBehaviour
{
    private RayTracingAccelerationStructure _ras;
    private RenderTexture _dxrTarget;
    private RayTracingShader _rayGenerationShader;
    public Camera cam;
    

    void Start()
    {
        InitRAS();
        InitRenderTexture();

        CommandBuffer command = new CommandBuffer();
        command.SetRayTracingTextureParam(_rayGenerationShader, "RenderTarget", _dxrTarget);
        command.SetRayTracingShaderPass(_rayGenerationShader, "RaytracingPass");
        command.SetRayTracingAccelerationStructure(_rayGenerationShader, "RAS", _ras);
        
        var inverseProjection = GL.GetGPUProjectionMatrix(cam.projectionMatrix, false).inverse;
        
        command.SetRayTracingMatrixParam(_rayGenerationShader, "_InverseProjection", inverseProjection);
        command.SetRayTracingMatrixParam(_rayGenerationShader, "_CameraToWorld", cam.cameraToWorldMatrix);
        command.SetRayTracingVectorParam(_rayGenerationShader, "_WorldSpaceCameraPos", cam.transform.position);
        
        command.DispatchRays(_rayGenerationShader, "RaygenShader", (uint)_dxrTarget.width, (uint)_dxrTarget.height, 1u, cam);
    }

    // Update is called once per frame
    void Update()
    {
        _ras.Build();
    }

    private void InitRAS()
    {
        var settings = new RayTracingAccelerationStructure.RASSettings
        {
            managementMode = RayTracingAccelerationStructure.ManagementMode.Automatic,
            layerMask = ~0,
            rayTracingModeMask = RayTracingAccelerationStructure.RayTracingModeMask.Everything
        };

        _ras = new RayTracingAccelerationStructure(settings);
    }
    private void InitRenderTexture()
    {
        if (_dxrTarget != null)
            return;

        _dxrTarget = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat,
            RenderTextureReadWrite.Linear);
        _dxrTarget.enableRandomWrite = true;
        _dxrTarget.Create();
    }

    private void InitRayGenerationShader()
    {
        _rayGenerationShader.SetTexture("_dxrTarget", _dxrTarget);
    }
}
