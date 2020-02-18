#include <iostream>
#include <string>
#include <sstream>
#include <cuda.h>

#include "CudaInterface.h"
#include "Internals.h"

using namespace device;

void ConcreteInterface::initialize() {
  cuInit(0); CHECK_ERR;

  // try to detect the amount of temp. memory from the environment
  const size_t Factor = 1024 * 1024 * 1024;  //!< bytes in 1 GB
  std::ostringstream Info;
  try {
    char *ValueString = std::getenv("DEVICE_STACK_MEM_SIZE");
    if (!ValueString) {
      Info << "DEVICE::INFO env. variable \"DEVICE_STACK_MEM_SIZE\" has not been set. "
           << "The default amount of the device memory (1 GB) "
           << "is going to be used to store temp. variables during execution of compute-kernels\n";
    }
    else {
      double RequestedStackMem = std::stod(std::string(ValueString));
      m_MaxStackMem = Factor * RequestedStackMem;
      Info << "DEVICE::INFO: env. variable \"DEVICE_STACK_MEM_SIZE\" has been detected. "
           << RequestedStackMem << "GB of the device memory is going to be used "
           << "to store temp. variables during execution of compute-kernels\n";
    }
  }
  catch (const std::invalid_argument &Err) {
    std::cout << "DEVICE::ERROR: " << Err.what() << ". File: " << __FILE__ << ", line: " << __LINE__ << '\n';
    throw Err;
  }
  catch (const std::out_of_range& Err) {
    std::cout << "DEVICE::ERROR: " << Err.what() << ". File: " << __FILE__ << ", line: " << __LINE__ << '\n';
    throw Err;
  }

  //TODO: move info into SeisSol logger
  std::cout << Info.str() << std::endl;

  m_StackMemory = (char*)allocGlobMem(m_MaxStackMem); CHECK_ERR;
};


void ConcreteInterface::finalize() {
  freeMem(m_StackMemory); CHECK_ERR;
  m_StackMemory = nullptr;
};


void ConcreteInterface::setDevice(int DeviceId) {
  m_CurrentDeviceId = DeviceId;
  cudaSetDevice(m_CurrentDeviceId); CHECK_ERR;
}


int ConcreteInterface::getNumDevices() {
  int numDevices{};
  cudaGetDeviceCount(&numDevices); CHECK_ERR;
  return numDevices;
}


void ConcreteInterface::synchDevice() {
  cudaDeviceSynchronize(); CHECK_ERR;
}


std::string ConcreteInterface::getDeviceInfoAsText(int DeviceId) {
  cudaDeviceProp Property;
  cudaGetDeviceProperties(&Property, DeviceId); CHECK_ERR;

  std::ostringstream Info;
  Info << "Name: " << Property.name << '\n';
  Info << "totalGlobalMem: " << Property.totalGlobalMem << '\n';
  Info << "sharedMemPerBlock: " << Property.sharedMemPerBlock << '\n';
  Info << "regsPerBlock: " << Property.regsPerBlock << '\n';
  Info << "warpSize: " << Property.warpSize << '\n';
  Info << "memPitch: " << Property.memPitch << '\n';
  Info << "maxThreadsPerBlock: " << Property.maxThreadsPerBlock << '\n';
  Info << "totalConstMem: " << Property.totalConstMem << '\n';
  Info << "clockRate: " << Property.clockRate << '\n';
  Info << "multiProcessorCount: " << Property.multiProcessorCount << '\n';
  Info << "integrated: " << Property.integrated << '\n';
  Info << "canMapHostMemory: " << Property.canMapHostMemory << '\n';
  Info << "computeMode: " << Property.computeMode << '\n';
  Info << "concurrentKernels: " << Property.concurrentKernels << '\n';
  Info << "pciBusID: " << Property.pciBusID << '\n';
  Info << "pciDeviceID: " << Property.pciDeviceID << '\n';

  return Info.str();
}