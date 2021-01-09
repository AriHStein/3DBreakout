using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Cinemachine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(CinemachineVirtualCamera))]
public class CinemachineOrbitalTransposerXAxisOverride : MonoBehaviour
{

    CinemachineOrbitalTransposer m_transposer;
    float m_axisValue;
    [SerializeField] float m_speed = 0.2f;

    private void Awake()
    {
        //cam = GetComponent<CinemachineVirtualCamera>();
        m_transposer = GetComponent<CinemachineVirtualCamera>().GetCinemachineComponent<CinemachineOrbitalTransposer>();
        m_axisValue = m_transposer.m_XAxis.Value;
    }

    private void Update()
    {
        m_transposer.m_XAxis.Value += m_axisValue;
    }

    public void MovePaddleInput(InputAction.CallbackContext context)
    {
        m_axisValue = m_speed * context.ReadValue<float>();
    }
}
