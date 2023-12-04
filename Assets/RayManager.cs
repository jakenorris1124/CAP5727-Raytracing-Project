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
    private RenderTexture _raytracingTarget;
    private RenderTexture _history;
    private RenderTexture _denoised;
    private Camera _cam;
    
    public RayTracingShader rayGenerationShader;
    public ComputeShader denoise;
    
    public Color upperSkyColor = Color.blue;
    public Color lowerSkyColor = Color.grey;

    public GameObject[] lights;
    public Material diffuse1;
    public Material diffuse2;
    public Material diffuse3;
    public Material specular;
    public Material glass;

    public Material[] materials;

    public int sampleCount = 5;

    private Random random = new Random();

    private bool indirect = true;
    private bool denoiseOn = true;
    
    
    private static readonly int Noisy = Shader.PropertyToID("Noisy");
    private static readonly int Denoised = Shader.PropertyToID("Denoised");
    private static readonly int History = Shader.PropertyToID("History");

    void Start()
    {
        _cam = GetComponent<Camera>();
        InitRAS();
        InitRenderTextures();
        InitRayGenerationShader();
        InitDenoiseShader();
        
        
        diffuse1.SetInteger("indirectLighting", 1);
        diffuse2.SetInteger("indirectLighting", 1);
        diffuse3.SetInteger("indirectLighting", 1);
    }

    // Update is called once per frame
    void Update()
    {
        _ras.Build();
        
        rayGenerationShader.SetMatrix("_CameraToWorld", _cam.cameraToWorldMatrix);
        rayGenerationShader.SetVector("_WorldSpaceCameraPos", _cam.transform.position);
        rayGenerationShader.SetInt("seed", random.Next());


        Vector4[] lightPositions = new Vector4[lights.Length];
        for (int i = 0; i < lights.Length; i++)
        {
            lightPositions[i] = lights[i].transform.position;
        }
        
        foreach (Material mat in materials)
        {
            mat.SetVectorArray("_LightPositions", lightPositions);
            mat.SetInteger("numLights", lightPositions.Length);
            mat.SetVector("_CameraPosition", _cam.transform.position);
        }

        if (Input.GetKeyDown(KeyCode.I))
        {
            indirect = !indirect;
            diffuse1.SetInteger("indirectLighting", indirect ? 1 : 0);
            diffuse2.SetInteger("indirectLighting", indirect ? 1 : 0);
            diffuse3.SetInteger("indirectLighting", indirect ? 1 : 0);
        }

        if (Input.GetKeyDown(KeyCode.N))
        {
            denoiseOn = !denoiseOn;
        }
    }
    
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        rayGenerationShader.Dispatch("RaygenShader", _raytracingTarget.width, _raytracingTarget.height, 1, _cam);

        if (denoiseOn)
        {
            denoise.Dispatch(0, _raytracingTarget.width / 8, _raytracingTarget.width / 8, 1);
            Graphics.Blit(_denoised, destination);
            Graphics.CopyTexture(_denoised, _history);
        }
        else
        {
            Graphics.Blit(_raytracingTarget, destination);
            Graphics.CopyTexture(_raytracingTarget, _history);
        }
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
    private void InitRenderTextures()
    {
        if (_raytracingTarget != null)
            return;

        _raytracingTarget = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat,
            RenderTextureReadWrite.Linear);
        _raytracingTarget.enableRandomWrite = true;
        _raytracingTarget.Create();
        
        _denoised = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat,
            RenderTextureReadWrite.Linear);
        _denoised.enableRandomWrite = true;
        _denoised.Create();
        
        _history = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBFloat,
            RenderTextureReadWrite.Linear);
        _history.enableRandomWrite = true;
        _history.Create();
    }

    private void InitRayGenerationShader()
    {
        rayGenerationShader.SetTexture("_dxrTarget", _raytracingTarget);
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

    private void InitDenoiseShader()
    {
        denoise.SetTexture(0, Noisy, _raytracingTarget);
        denoise.SetTexture(0, History, _history);
        denoise.SetTexture(0, Denoised, _denoised);
    }
}
