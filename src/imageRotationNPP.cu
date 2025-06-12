/* Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *  * Neither the name of NVIDIA CORPORATION nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#if defined(WIN32) || defined(_WIN32) || defined(WIN64) || defined(_WIN64)
#define WINDOWS_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#pragma warning(disable : 4819)
#endif


#include <FreeImage.h>
#include <cuda_runtime.h>
#include <cmath>
#include <cstdio>

// Simple 45°-rotation kernel (nearest-neighbor)
__global__ void rotateKernel(uchar4* in, uchar4* out, int w, int h, float angleRad) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= w || y >= h) return;

    float cx = w * 0.5f, cy = h * 0.5f;
    float xr =  (x - cx) * cosf(angleRad) + (y - cy) * sinf(angleRad) + cx;
    float yr = -(x - cx) * sinf(angleRad) + (y - cy) * cosf(angleRad) + cy;
    int xi = __float2int_rn(xr), yi = __float2int_rn(yr);

    if (xi >= 0 && xi < w && yi >= 0 && yi < h)
        out[y * w + x] = in[yi * w + xi];
    else
        out[y * w + x] = make_uchar4(0,0,0,255);
}

int main(int argc, char** argv) {
    if (argc != 4) {
        printf("Usage: %s input.png output.png angle\n", argv[0]);
        return 1;
    }
    const char* inPath  = argv[1];
    const char* outPath = argv[2];
    float angleDeg = atof(argv[3]);
    float angleRad = angleDeg * 3.14159265f / 180.0f;

    FreeImage_Initialise();
    FIBITMAP* dib = FreeImage_Load(FIF_PNG, inPath);
    FIBITMAP* dib32 = FreeImage_ConvertTo32Bits(dib);
    FreeImage_Unload(dib);
    int w = FreeImage_GetWidth(dib32);
    int h = FreeImage_GetHeight(dib32);
    uchar4* hostData = (uchar4*)FreeImage_GetBits(dib32);

    size_t size = w * h * sizeof(uchar4);
    uchar4 *d_in, *d_out;
    cudaMalloc(&d_in,  size);
    cudaMalloc(&d_out, size);
    cudaMemcpy(d_in, hostData, size, cudaMemcpyHostToDevice);

    dim3 block(16,16), grid((w+15)/16,(h+15)/16);
    rotateKernel<<<grid,block>>>(d_in, d_out, w, h, angleRad);
    cudaDeviceSynchronize();

    cudaMemcpy(hostData, d_out, size, cudaMemcpyDeviceToHost);
    cudaFree(d_in);
    cudaFree(d_out);

    FreeImage_Save(FIF_PNG, dib32, outPath);
    FreeImage_Unload(dib32);
    FreeImage_DeInitialise();
    return 0;
}
