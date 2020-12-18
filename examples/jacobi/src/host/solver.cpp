#include "helper.hpp"
#include "matrix_manip.hpp"
#include "solvers.hpp"
#include "subroutines.hpp"
#include <algorithm>
#include <cassert>
#include <functional>
#include <iostream>
#include <limits>

void host::solver(const SolverSettingsT &settings, const CpuMatrixDataT &matrix, const VectorT &inputRhs, VectorT &x) {

  std::cout << "Computation of X^k using the CPU" << std::endl;

  // allocate all necessary data structs
  const WorkSpaceT &ws = matrix.info.ws;
  const RangeT range = matrix.info.range;
  VectorAssembler assembler(ws, range);

  VectorT residual(matrix.info.numRows, std::numeric_limits<real>::max());
  VectorT temp(matrix.info.numRows, 0.0);
  real infNorm = std::numeric_limits<real>::max();
  unsigned currentIter{0};

  // assume that RHS is distributed. Thus, let's assemble it
  VectorT rhs(inputRhs.size(), 0.0);
  assembler.assemble(const_cast<real*>(inputRhs.data()), const_cast<real*>(rhs.data()));

  // compute diag and LU matrices
  VectorT invDiag;
  CpuMatrixDataT lu(MatrixInfoT(WorkSpaceT{}, matrix.info.numRows, 0));
  std::tie(invDiag, lu) = getDLU(matrix);

  // compute inverse diagonal matrix
  std::transform(invDiag.begin(), invDiag.end(), invDiag.begin(), [](const real &diag) {
    assert(diag != 0.0 && "diag element cannot be equal to zero");
    return 1.0 / diag;
  });

  VectorT tempX(x.size(), 0.0);
  // start solver
  while ((infNorm > settings.eps) and (currentIter <= settings.maxNumIters)) {

    // update X
    multMatVec(lu, x, temp);
    manipVectors(range, rhs, temp, x, std::minus<real>());
    manipVectors(range, invDiag, x, x, std::multiplies<real>());

    assembler.assemble(const_cast<real*>(x.data()), const_cast<real*>(tempX.data()));
    x.swap(tempX);
    // Compute residual and print output
    if ((currentIter % settings.printInfoNumIters) == 0) {

      multMatVec(matrix, x, temp);
      manipVectors(range, rhs, temp, residual, std::minus<real>());
      auto localInfNorm = getInfNorm(range, residual);
#ifdef USE_MPI
      MPI_Allreduce(&localInfNorm, &infNorm, 1, MPI_CUSTOM_REAL, MPI_MAX, ws.comm);
#else
      infNorm = localInfNorm;
#endif
      std::stringstream stream;
      stream << "Current iter: " << currentIter << "; Residual: " << infNorm;
      Logger(ws, 0) << stream;
    }

    ++currentIter;
  }
}
