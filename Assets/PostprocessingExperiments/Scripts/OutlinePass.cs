using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class OutlinePass : DrawFullscreenPass
{
    
    public OutlinePass(string tag) : base(tag) 
    {
        //int index = Shader.Find("Unlit/Outline").FindPropertyIndex("_ClipToView");
        //clipToViewID = Shader.Find("Unlit/Outline").GetPropertyNameId(index);

        clipToViewID = Shader.Find("Unlit/Outline").FindPropertyIndex("_ClipToView");
    }

    int clipToViewID;

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);

        //Matrix4x4 clipToView = renderingData.cameraData.GetGPUProjectionMatrix().inverse;
        Matrix4x4 clipToView = GL.GetGPUProjectionMatrix(renderingData.cameraData.GetProjectionMatrix(), true).inverse;
        cmd.SetGlobalMatrix(clipToViewID, clipToView);

        if (isSourceAndDestinationSameTarget)
        {
            Blit(cmd, source, destination, settings.blitMaterial, settings.blitMaterialPassIndex);
            Blit(cmd, destination, source);
        }
        else
        {
            Blit(cmd, source, destination, settings.blitMaterial, settings.blitMaterialPassIndex);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}
