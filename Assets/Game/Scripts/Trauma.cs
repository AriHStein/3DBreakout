using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Trauma : MonoBehaviour
{
    public static Trauma Current { get; private set; }

    float m_value;
    public static float Value 
    { 
        get { return Current.m_value; }
        set { Current.m_value = Mathf.Clamp01(value); }
    }

    [SerializeField] float m_falloffTime;

    // Start is called before the first frame update
    void Awake()
    {
        if(Current != null)
        {
            Destroy(Current);
        }

        Current = this;
    }

    private void OnDestroy()
    {
        if(Current == this)
        {
            Current = null;
        }
    }

    // Update is called once per frame
    void Update()
    {
        Value -= (1 / m_falloffTime) * Time.deltaTime;
    }
}
