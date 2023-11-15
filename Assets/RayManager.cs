using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Serialization;
using Random = System.Random;

public class RayManager : MonoBehaviour
{
    private RayTracingAccelerationStructure _ras;
    private RenderTexture _dxrTarget;
    private Camera _cam;
    
    public RayTracingShader rayGenerationShader;
    
    public Color upperSkyColor = Color.blue;
    public Color lowerSkyColor = Color.grey;

    public GameObject lightPosition;
    public Material diffuse1;
    public Material diffuse2;
    public Material specular;

    public int sampleCount = 5;

    private Random random = new Random();
    
    
    void Start()
    {
        _cam = GetComponent<Camera>();
        InitRAS();
        InitRenderTexture();
        InitRayGenerationShader();
    }

    // Update is called once per frame
    void Update()
    {
        _ras.Build();
        
        rayGenerationShader.SetMatrix("_CameraToWorld", _cam.cameraToWorldMatrix);
        rayGenerationShader.SetVector("_WorldSpaceCameraPos", _cam.transform.position);
        rayGenerationShader.SetVector("lightPosition", lightPosition.transform.position);
        rayGenerationShader.SetInt("seed", random.Next());
        
        diffuse1.SetVector("_LightPosition", lightPosition.transform.position);
        diffuse2.SetVector("_LightPosition", lightPosition.transform.position);
        specular.SetVector("_CameraPosition", _cam.transform.position);
    }
    
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        rayGenerationShader.Dispatch("RaygenShader", _dxrTarget.width, _dxrTarget.height, 1, _cam);
        Graphics.Blit(_dxrTarget, destination);
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
        
        _ras.Build();
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
        rayGenerationShader.SetTexture("_dxrTarget", _dxrTarget);
        rayGenerationShader.SetShaderPass("RaytracingPass");
        rayGenerationShader.SetAccelerationStructure("_ras", _ras);
        
        var inverseProjection = GL.GetGPUProjectionMatrix(_cam.projectionMatrix, false).inverse;
        rayGenerationShader.SetMatrix("_InverseProjection", inverseProjection);
        rayGenerationShader.SetMatrix("_CameraToWorld", _cam.cameraToWorldMatrix);
        rayGenerationShader.SetVector("_WorldSpaceCameraPos", _cam.transform.position);
        
        rayGenerationShader.SetVector("_upperSkyColor", upperSkyColor.gamma);
        rayGenerationShader.SetVector("_lowerSkyColor", lowerSkyColor.gamma);
        
        rayGenerationShader.SetInt("sampleCount", sampleCount);
    }
}
