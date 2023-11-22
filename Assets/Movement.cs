using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.AI;
using UnityEngine.InputSystem;

public class Movement : MonoBehaviour
{
    public GameObject start;
    public GameObject end;
    private float position = 0f;

    public float delta = 0.01f;

    private bool on = true;
    public KeyCode toggle = KeyCode.G;

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(toggle))
            on = !on;

        if (on)
        {
            transform.position = Vector3.Lerp(start.transform.position, end.transform.position, position);

            position += delta;

            if (position is >= 1f or < 0f)
            {
                delta *= -1f;
            }
        }
    }
}