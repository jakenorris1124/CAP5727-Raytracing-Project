using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Demo : MonoBehaviour
{
    private int _sceneIndex;
    private int _sceneCount;
    // Start is called before the first frame update
    void Start()
    {
        _sceneIndex = SceneManager.GetActiveScene().buildIndex;
        _sceneCount = SceneManager.sceneCount;
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.R))
        {
            SceneManager.LoadScene(_sceneIndex);
        }

        if (Input.GetKeyDown(KeyCode.L))
        {
            SceneManager.LoadScene(_sceneIndex + 1);
        }
    }
}
