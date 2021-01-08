using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

[RequireComponent(typeof(Rigidbody))]
[RequireComponent(typeof(BoxCollider))]
public class PaddleController : MonoBehaviour
{
    [SerializeField] float m_maxPaddleSpeed = 3f;
    [SerializeField] float m_edgeBuffer = 3f;
    [SerializeField] float m_accelerationTime = 0.5f;
    [SerializeField] GameObject m_ballPrefab = default;
    [SerializeField] Transform m_ballSpawnOrigin = default;
    [SerializeField] Cinemachine.CinemachineTargetGroup m_cameraTargetGroup = default;


    Rigidbody rb;
    BoxCollider m_collider;
    Camera m_camera;
    Vector2 m_moveInput;
    Vector3 m_velocity;
    Vector3 m_velocitySmoothing;

    Ball m_ball;

    void Awake()
    {
        rb = GetComponent<Rigidbody>();
        m_collider = GetComponent<BoxCollider>();
        m_camera = Camera.main;

        m_moveInput = Vector2.zero;
        m_velocity = m_velocitySmoothing = Vector3.zero;
    }

    private void Start()
    {
        SpawnBall();
    }

    private void FixedUpdate()
    {
        // Translate movement input into "camera space"
        // So that pressuing "up" will always translate to forward movement
        // "right" will always translate to right movement, etc.
        // This is a bit hacky--I figured it out more through trial and error than concrete math. But it works.
        Vector3 targetVelocity = new Vector3(m_moveInput.x, 0, m_moveInput.y);
        targetVelocity = m_camera.transform.rotation * targetVelocity;
        targetVelocity.y = 0;


        targetVelocity = targetVelocity.normalized * m_maxPaddleSpeed;
        m_velocity = Vector3.SmoothDamp(m_velocity, targetVelocity, ref m_velocitySmoothing, m_accelerationTime, m_maxPaddleSpeed, Time.fixedDeltaTime);
        Vector3 move = m_velocity * Time.fixedDeltaTime;

        // Custom collision detection with the edge of the world.
        // Just writing this seemed easier than figuring out how to get a kinematic rigidbody to collide correctly
        Bounds bounds = m_collider.bounds;
        if(move.x > 0)
        {
            Vector3 rayOrigin = transform.position + Vector3.right * bounds.extents.x;
            Debug.DrawLine(rayOrigin, rayOrigin + Vector3.right * m_edgeBuffer, Color.red);
            if (Physics.Raycast(rayOrigin, Vector3.right, m_edgeBuffer))
            {
                move.x = 0;
                m_velocity.x = 0;
                m_velocitySmoothing.x = 0;
            }
        }
        else if (move.x < 0)
        {
            Vector3 rayOrigin = transform.position + Vector3.left * bounds.extents.x;
            Debug.DrawLine(rayOrigin, rayOrigin + Vector3.left * m_edgeBuffer, Color.red);
            if (Physics.Raycast(rayOrigin, Vector3.left, m_edgeBuffer))
            {
                move.x = 0;
                m_velocity.x = 0;
                m_velocitySmoothing.x = 0;
            }
        }

        if (move.z > 0)
        {
            Vector3 rayOrigin = transform.position + Vector3.forward * bounds.extents.z;
            Debug.DrawLine(rayOrigin, rayOrigin + Vector3.forward * m_edgeBuffer, Color.red);
            if (Physics.Raycast(rayOrigin, Vector3.forward, m_edgeBuffer))
            {
                move.z = 0;
                m_velocity.z = 0;
                m_velocitySmoothing.z = 0;
            }
        }
        else if (move.z < 0)
        {
            Vector3 rayOrigin = transform.position + Vector3.back * bounds.extents.z;
            Debug.DrawLine(rayOrigin, rayOrigin + Vector3.back * m_edgeBuffer, Color.red);
            if (Physics.Raycast(rayOrigin, Vector3.back, m_edgeBuffer))
            {
                move.z = 0;
                m_velocity.z = 0;
                m_velocitySmoothing.z = 0;
            }
        }

        rb.MovePosition(transform.position + move);
    }

    void SpawnBall()
    {
        GameObject go = Instantiate(m_ballPrefab, m_ballSpawnOrigin);
        m_ball = go.GetComponent<Ball>();
        m_ball.BallDestroyedEvent += OnBallDestroyed;

        m_cameraTargetGroup.AddMember(go.transform, 4, 1f);
    }

    void OnBallDestroyed(Ball ball)
    {
        m_cameraTargetGroup.RemoveMember(ball.transform);
        
        SpawnBall();
    }

    public void MovePaddleInput(InputAction.CallbackContext context)
    {
        m_moveInput = context.ReadValue<Vector2>();
    }

    public void FireBallInput(InputAction.CallbackContext context)
    {
        if(!context.ReadValueAsButton())
        {
            return;
        }

        if(m_ball == null)
        {
            return;
        }

        Vector3 dir = Random.onUnitSphere;
        dir.y = 1;

        m_ball.Launch(dir.normalized);
        m_ball = null;
    }
}
