#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <math.h>

// Define the image width and height
#define WIDTH  800
#define HEIGHT 600

// Maximum number of iterations
#define MAX_ITER 1000

// Kernel to compute the Mandelbrot set
__global__ void mandelbrot_kernel(unsigned char *image, int width, int height, 
                                  float x_min, float x_max, float y_min, float y_max,
                                  int max_iter) {
    // Calculate our pixel's location
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    // Check if we are within the image bounds
    if (x < width && y < height) {
        // Map pixel position to a point in the complex plane
        float x0 = x_min + x * (x_max - x_min) / width;
        float y0 = y_min + y * (y_max - y_min) / height;

        // Initialize z = 0
        float real = 0.0f;
        float imag = 0.0f;
        float real_sq = 0.0f;
        float imag_sq = 0.0f;

        int iter = 0;
        while (iter < max_iter && (real_sq + imag_sq) < 4.0f) {
            // z = z^2 + c
            float temp_real = real_sq - imag_sq + x0;
            float temp_imag = 2.0f * real * imag + y0;
            real = temp_real;
            imag = temp_imag;

            // Update squares for next iteration
            real_sq = real * real;
            imag_sq = imag * imag;
            iter++;
        }

        // Set pixel color based on iteration count
        // Simple grayscale: 0 = black (inside), max_iter = white (outside)
        // We'll map to 0-255 for grayscale
        unsigned char color = (iter == max_iter) ? 0 : 255 * (iter / (float)max_iter);
        image[y * width + x] = color;
    }
}

int main(void) {
    // Allocate host memory for the image
    unsigned char *h_image = (unsigned char*)malloc(WIDTH * HEIGHT * sizeof(unsigned char));
    if (h_image == NULL) {
        fprintf(stderr, "Failed to allocate host memory for image.\n");
        return 1;
    }

    // Allocate device memory
    unsigned char *d_image;
    cudaMalloc((void**)&d_image, WIDTH * HEIGHT * sizeof(unsigned char));
    if (d_image == NULL) {
        fprintf(stderr, "Failed to allocate device memory for image.\n");
        free(h_image);
        return 1;
    }

    // Define the region of the complex plane to render
    float x_min = -2.0f, x_max = 1.0f;
    float y_min = -1.5f, y_max = 1.5f;

    // Configure kernel launch parameters
    dim3 blockSize(16, 16);
    dim3 gridSize((WIDTH + blockSize.x - 1) / blockSize.x,
                  (HEIGHT + blockSize.y - 1) / blockSize.y);

    // Launch the kernel
    mandelbrot_kernel<<<gridSize, blockSize>>>(d_image, WIDTH, HEIGHT, 
                                               x_min, x_max, y_min, y_max, MAX_ITER);

    // Check for kernel launch errors
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        fprintf(stderr, "Kernel launch error: %s\n", cudaGetErrorString(err));
        cudaFree(d_image);
        free(h_image);
        return 1;
    }

    // Copy the result from device to host
    cudaMemcpy(h_image, d_image, WIDTH * HEIGHT * sizeof(unsigned char), 
               cudaMemcpyDeviceToHost);

    // Free device memory
    cudaFree(d_image);

    // Save the image as a PPM file (grayscale)
    FILE *fp = fopen("mandelbrot.ppm", "wb");
    if (fp == NULL) {
        fprintf(stderr, "Failed to open output file.\n");
        free(h_image);
        return 1;
    }

    // Write PPM header
    fprintf(fp, "P5\n%d %d\n255\n", WIDTH, HEIGHT);
    // Write pixel data
    fwrite(h_image, sizeof(unsigned char), WIDTH * HEIGHT, fp);
    fclose(fp);

    // Free host memory
    free(h_image);

    printf("Mandelbrot image saved to mandelbrot.ppm\n");
    return 0;
}