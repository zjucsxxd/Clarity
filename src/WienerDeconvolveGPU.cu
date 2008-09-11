#include <cuda.h>
#include <stdio.h>

#include "ComplexCUDA.h"
#include "WienerDeconvolveGPU.h"

#define BLOCKS 16
#define THREADS_PER_BLOCK 128


__global__
void
WienerCUDAKernel(
   int n, float scale, Complex* inFT, Complex* psfFT, 
   Complex* outFT, float epsilon) {

   const int tid     = __mul24(blockIdx.x, blockDim.x) + threadIdx.x;
   const int threadN = __mul24(blockDim.x, gridDim.x);

   for (int voxelID = tid; voxelID < n; voxelID += threadN) {
      Complex H = psfFT[voxelID];
      Complex HConj = ComplexConjugate(H);
      float HMagSquared = ComplexMagnitudeSquared(H);
      HConj = ComplexScale(HConj, 1.0f / (HMagSquared + epsilon));
      outFT[voxelID] = ComplexMultiplyAndScale(
         HConj, inFT[voxelID], scale);
   }
}


extern "C"
void
WienerDeconvolveKernelGPU(
   int nx, int ny, int nz, float* inFT, float* psfFT, 
   float* outFT, float epsilon) {

   int n = nz*ny*(nx/2 + 1);
   dim3 grid(BLOCKS);
   dim3 block(THREADS_PER_BLOCK);
   float scale = 1.0f / ((float) nx*ny*nz);

   WienerCUDAKernel<<<grid, block>>>(n, scale, (Complex*)inFT,
      (Complex*)psfFT, (Complex*)outFT, epsilon);

   cudaError result = cudaThreadSynchronize();
   if (result != cudaSuccess) {
      fprintf(stderr, "CUDA error: %s in file '%s' in line %i : %s.\n",
         "WienerCUDAKernel failed", __FILE__, __LINE__, cudaGetErrorString(result));
   }
}
