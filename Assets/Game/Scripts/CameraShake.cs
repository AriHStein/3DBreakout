using Cinemachine;
using UnityEngine;

[RequireComponent(typeof(CinemachineVirtualCamera))]
public class CameraShake : MonoBehaviour
{
    [SerializeField] float m_maxShakeMagnitue = 3;
    [SerializeField] float m_shakeFrequency = 5;
    [SerializeField] float m_distanceScaleFactor = 20;

    CinemachineVirtualCamera m_camera;
    CinemachineBasicMultiChannelPerlin m_noise;

    // Start is called before the first frame update
    void Awake()
    {
        m_camera = GetComponent<CinemachineVirtualCamera>();
        m_noise = m_camera.GetCinemachineComponent<CinemachineBasicMultiChannelPerlin>();
        m_noise.m_AmplitudeGain = 0;
        m_noise.m_FrequencyGain = m_shakeFrequency;
    }

    // Update is called once per frame
    void Update()
    {
        float distance = Mathf.Clamp01(m_distanceScaleFactor / Vector3.Distance(transform.position, Trauma.Current.transform.position));


        //float distanceScaledTrauma = Mathf.Clamp01(m_distanceScaleFactor / Vector3.Distance(transform.position, Trauma.Current.transform.position) * Trauma.Value);
        m_noise.m_AmplitudeGain = m_maxShakeMagnitue * Mathf.Pow(distance * Trauma.Value, 3);
    }
}
