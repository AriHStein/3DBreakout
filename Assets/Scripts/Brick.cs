using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class Brick : MonoBehaviour
{
    [SerializeField] int m_maxHealth = 3;
    int m_currentHealth;

    MaterialPropertyBlock m_materialProperties;
    [SerializeField] Color m_baseColor;
    Renderer m_renderer;

    private void Awake()
    {
        m_currentHealth = m_maxHealth;
        m_renderer = GetComponent<Renderer>();
        m_materialProperties = new MaterialPropertyBlock();
        m_materialProperties.SetColor("_BaseColor", m_baseColor);
        m_renderer.SetPropertyBlock(m_materialProperties);
    }

    private void OnCollisionEnter(Collision collision)
    {
        if(collision.collider.CompareTag("Ball"))
        {
            TakeDamage();
        }
    }

    void TakeDamage()
    {
        m_currentHealth--;
        m_materialProperties.SetColor("_BaseColor", Color.Lerp(m_baseColor, Color.black, (m_maxHealth - m_currentHealth) / (float)m_maxHealth));
        m_renderer.SetPropertyBlock(m_materialProperties);
        if(m_currentHealth <= 0)
        {
            Explode();
        }
    }

    void Explode()
    {
        Destroy(gameObject);
    }
}
