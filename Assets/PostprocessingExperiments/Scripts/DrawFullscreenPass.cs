using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

public class DrawFullscreenPass : ScriptableRenderPass
{
    public FilterMode filterMode { get; set; }
    public DrawFullscreenFeature.Settings settings;

    protected RenderTargetIdentifier source;
    protected RenderTargetIdentifier destination;
    protected int temporaryRTId = Shader.PropertyToID("_TempRT");

    protected int sourceId;
    protected int destinationId;
    protected bool isSourceAndDestinationSameTarget;

    protected string m_ProfilerTag;

    public DrawFullscreenPass(string tag)
    {
        m_ProfilerTag = tag;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {        
        RenderTextureDescriptor blitTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        blitTargetDescriptor.depthBufferBits = 0;

        isSourceAndDestinationSameTarget = settings.sourceType == settings.destinationType &&
            (settings.sourceType == BufferType.CameraColor || settings.sourceTextureId == settings.destinationTextureId);

        var renderer = renderingData.cameraData.renderer;

        if(settings.sourceType == BufferType.CameraColor)
        {
            sourceId = -1;
            source = renderer.cameraColorTarget;
        }
        else
        {
            sourceId = Shader.PropertyToID(settings.sourceTextureId);
            cmd.GetTemporaryRT(sourceId, blitTargetDescriptor, filterMode);
            source = new RenderTargetIdentifier(sourceId);
        }

        if (isSourceAndDestinationSameTarget)
        {
            destinationId = temporaryRTId;
            cmd.GetTemporaryRT(destinationId, blitTargetDescriptor, filterMode);
            destination = new RenderTargetIdentifier(destinationId);
        }
        else if(settings.destinationType == BufferType.CameraColor)
        {
            destinationId = -1;
            destination = renderer.cameraColorTarget;
        }
        else
        {
            destinationId = Shader.PropertyToID(settings.destinationTextureId);
            cmd.GetTemporaryRT(destinationId, blitTargetDescriptor, filterMode);
            destination = new RenderTargetIdentifier(destinationId);
        }
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);

        if(isSourceAndDestinationSameTarget)
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

    public override void FrameCleanup(CommandBuffer cmd)
    {
        if(destinationId != -1)
        {
            cmd.ReleaseTemporaryRT(destinationId);
        }

        if(source == destination && sourceId != -1)
        {
            cmd.ReleaseTemporaryRT(sourceId);
        }
    }
}
