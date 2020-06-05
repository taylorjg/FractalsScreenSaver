# Description

This repo contains a macOS screensaver written in Swift/Metal that draws fractals.

# Now I understand

I have implemented similar code to draw fractals a couple of times previously.

The first time, I wrote the code in C#, used WPF for drawing and used OpenCL for GPGPU processing to calculate the pixels values - see [this repo](https://github.com/taylorjg/FractalsWpf). 

The second time, I used JavaScript and WebGL - loosely based on [this example](https://github.com/gpjt/webgl-lessons/blob/master/example01/index.html). Even though it all worked fine, I didn't fully understand the WebGL implementation. It is only after implementing this code again in Swift/Metal that I finally understand how the code works! Also, I have spent quite a lot of time over the past few months reading books on THREE.js, WebGL, OpenGL and Metal.

The missing piece in my understanding was the rasterization of primitives and the interpolation of vertex shader outputs. We pass a fixed quad to the vertex shader - 6 vertices forming 2 triangles that fill the viewport. So the vertex shader is only invoked 6 times - once per vertex. But the fragment shader is invoked for each pixel e.g. 2880 x 1800 = 5184000 times! More details can be found [here](https://en.wikibooks.org/wiki/GLSL_Programming/Rasterization).

# TODO

* Periodically, choose a random fractal region to show
* Add a config sheet with various settings
* Add a thumbnail image that will appear in Screen Saver preferences

# Links

* Books
  * [Learn Three.js: Programming 3D animations and visualizations for the web with HTML5 and WebGL, 3rd Edition](https://www.amazon.co.uk/Learn-Three-js-Programming-animations-visualizations-ebook/dp/B07H2WJD1P)
  * [Real-Time 3D Graphics with WebGL 2: Build interactive 3D applications with JavaScript and WebGL 2 (OpenGL ES 3.0), 2nd Edition](https://www.amazon.co.uk/Real-Time-Graphics-WebGL-interactive-applications-ebook/dp/B07GVNQLH5)
  * [OpenGL 4 Shading Language Cookbook: Build high-quality, real-time 3D graphics with OpenGL 4.6, GLSL 4.6 and C++17, 3rd Edition](https://www.amazon.co.uk/OpenGL-Shading-Language-Cookbook-high-quality/dp/1789342252)
  * [Metal by Tutorials](https://www.amazon.co.uk/Metal-Tutorials-Second-Beginning-Development/dp/1942878982)
