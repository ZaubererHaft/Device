#include "hip/hip_runtime.h"
#include <assert.h>
#include <sstream>
#include <iostream>

#include "HipWrappedAPI.h"
#include "Internals.h"

using namespace device;

void* ConcreteAPI::allocGlobMem(size_t size) {
  void *devPtr;
  hipMalloc(&devPtr, size); CHECK_ERR;
  m_statistics.allocatedMemBytes += size;
  m_memToSizeMap[devPtr] = size;
  return devPtr;
}


void* ConcreteAPI::allocUnifiedMem(size_t size) {
  void *devPtr;
  hipMallocManaged(&devPtr, size, hipMemAttachGlobal); CHECK_ERR;
  m_statistics.allocatedMemBytes += size;
  m_statistics.allocatedUnifiedMemBytes += size;
  m_memToSizeMap[devPtr] = size;
  return devPtr;
}


void* ConcreteAPI::allocPinnedMem(size_t size) {
  void *devPtr;
  hipHostMalloc(&devPtr, size); CHECK_ERR;
  m_statistics.allocatedMemBytes += size;
  m_memToSizeMap[devPtr] = size;
  return devPtr;
}


void ConcreteAPI::freeMem(void *devPtr) {
  assert((m_memToSizeMap.find(devPtr) != m_memToSizeMap.end())
         && "DEVICE: an attempt to delete mem. which has not been allocated. unknown pointer");
  m_statistics.deallocatedMemBytes += m_memToSizeMap[devPtr];
  hipFree(devPtr); CHECK_ERR;
}


void ConcreteAPI::freePinnedMem(void *devPtr) {
  assert((m_memToSizeMap.find(devPtr) != m_memToSizeMap.end())
         && "DEVICE: an attempt to delete mem. which has not been allocated. unknown pointer");
  m_statistics.deallocatedMemBytes += m_memToSizeMap[devPtr];
  hipHostFree(devPtr); CHECK_ERR;
}


char* ConcreteAPI::getStackMemory(size_t requestedBytes) {
  assert(((m_stackMemByteCounter + requestedBytes) < m_maxStackMem) && "DEVICE:: run out of a device stack memory");
  char *mem = &m_stackMemory[m_stackMemByteCounter];
  m_stackMemByteCounter += requestedBytes;
  m_stackMemMeter.push(requestedBytes);
  return mem;
}


void ConcreteAPI::popStackMemory() {
  m_stackMemByteCounter -= m_stackMemMeter.top();
  m_stackMemMeter.pop();
}

std::string ConcreteAPI::getMemLeaksReport() {
  std::ostringstream report{};
  report << "Memory Leaks, bytes: " << (m_statistics.allocatedMemBytes - m_statistics.deallocatedMemBytes) << '\n';
  report << "Stack Memory Leaks, bytes: " << m_stackMemByteCounter << '\n';
  return report.str();
}

size_t ConcreteAPI::getMaxAvailableMem() {
  hipDeviceProp_t property;
  hipGetDeviceProperties(&property, m_currentDeviceId); CHECK_ERR;
  return property.totalGlobalMem;
}

size_t ConcreteAPI::getCurrentlyOccupiedMem() {
  return m_statistics.allocatedMemBytes;
}

size_t ConcreteAPI::getCurrentlyOccupiedUnifiedMem() {
  return m_statistics.allocatedUnifiedMemBytes;
}