using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Rigidbody))]
public class Ball : MonoBehaviour
{
    [SerializeField] float m_launchSpeed;
    Rigidbody rb;

    public event System.Action<Ball> BallDestroyedEvent;

    void Start()
    {
        rb = GetComponent<Rigidbody>();
        rb.isKinematic = true;

        Trauma.Value = 0;
    }

    private void FixedUpdate()
    {
        if(rb.velocity.magnitude > m_launchSpeed)
        {
            rb.velocity = rb.velocity.normalized * m_launchSpeed;
        }
    }

    public void Launch(Vector3 direction)
    {
        transform.SetParent(null);
        rb.isKinematic = false;
        rb.AddForce(direction * m_launchSpeed, ForceMode.Impulse);
    }

    private void OnCollisionEnter(Collision collision)
    {
        Trauma.Value += 1;
    }

    private void OnTriggerEnter(Collider other)
    {
        if(other.CompareTag("Respawn"))
        {
            Explode();
        }
    }

    void Explode()
    {
        BallDestroyedEvent?.Invoke(this);
        Destroy(gameObject);
    }
}
