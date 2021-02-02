#include "AbstractAPI.h"
#include "interfaces/cuda/Internals.h"
#include <device.h>
#include <cassert>

namespace device {
  __global__ void kernel_streamBatchedData(real **baseSrcPtr,
                                           real **baseDstPtr,
                                           unsigned elementSize) {

    real *srcElement = baseSrcPtr[blockIdx.x];
    real *dstElement = baseDstPtr[blockIdx.x];
    for (int index = threadIdx.x; index < elementSize; index += blockDim.x) {
      dstElement[index] = srcElement[index];
    }
  }

  void Algorithms::streamBatchedData(real **baseSrcPtr,
                                     real **baseDstPtr,
                                     unsigned elementSize,
                                     unsigned numElements) {
    dim3 block(internals::WARP_SIZE, 1, 1);
    dim3 grid(numElements, 1, 1);
    kernel_streamBatchedData<<<grid, block>>>(baseSrcPtr, baseDstPtr, elementSize); CHECK_ERR;
  }


//--------------------------------------------------------------------------------------------------
  __global__ void kernel_accumulateBatchedData(real **baseSrcPtr,
                                               real **baseDstPtr,
                                               unsigned elementSize) {

    real *srcElement = baseSrcPtr[blockIdx.x];
    real *dstElement = baseDstPtr[blockIdx.x];
    for (int index = threadIdx.x; index < elementSize; index += blockDim.x) {
      dstElement[index] += srcElement[index];
    }
  }

  void Algorithms::accumulateBatchedData(real **baseSrcPtr,
                                         real **baseDstPtr,
                                         unsigned elementSize,
                                         unsigned numElements) {
    dim3 block(internals::WARP_SIZE, 1, 1);
    dim3 grid(numElements, 1, 1);
    kernel_accumulateBatchedData<<<grid, block>>>(baseSrcPtr, baseDstPtr, elementSize); CHECK_ERR;
  }

//--------------------------------------------------------------------------------------------------
  __global__ void kernel_touchBatchedMemory(real **basePtr, unsigned elementSize, bool clean) {
    real *element = basePtr[blockIdx.x];
    int id = threadIdx.x;
    while (id < elementSize) {
      if (clean) {
        element[id] = 0.0;
      } else {
        real value = element[id];
        // Do something dummy here. We just need to check the pointers point to valid memory locations.
        // Avoid compiler optimization. Possibly, implement a dummy code with asm.
        value += 1.0;
        value -= 1.0;
      }
      id += blockDim.x;
    }
  }

  void Algorithms::touchBatchedMemory(real **basePtr, unsigned elementSize, unsigned numElements, bool clean) {
    dim3 block(256, 1, 1);
    dim3 grid(numElements, 1, 1);
    kernel_touchBatchedMemory<<<grid, block>>>(basePtr, elementSize, clean); CHECK_ERR;
  }
} // namespace device