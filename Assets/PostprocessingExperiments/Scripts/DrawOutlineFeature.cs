using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class DrawOutlineFeature : DrawFullscreenFeature
{
    public override void Create()
    {
        blitPass = new OutlinePass(name);
    }
}
