using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Experimental.Rendering;

public class RayManager : MonoBehaviour
{
    public RayTracingAccelerationStructure RAS;
    // Start is called before the first frame update
    void OnEnable()
    {
        var settings = new RayTracingAccelerationStructure.RASSettings();
        settings.managementMode = RayTracingAccelerationStructure.ManagementMode.Automatic;
        settings.rayTracingModeMask = RayTracingAccelerationStructure.RayTracingModeMask.Everything;

        RAS = new RayTracingAccelerationStructure(settings);
    }

    // Update is called once per frame
    void Update()
    {
        RAS.Build();
    }
}
