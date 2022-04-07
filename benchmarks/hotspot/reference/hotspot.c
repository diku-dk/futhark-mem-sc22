#include <CL/cl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/time.h>
#include <assert.h>
#include "common.h"

#ifdef RD_WG_SIZE_0_0
#define BLOCK_SIZE RD_WG_SIZE_0_0
#elif defined(RD_WG_SIZE_0)
#define BLOCK_SIZE RD_WG_SIZE_0
#elif defined(RD_WG_SIZE)
#define BLOCK_SIZE RD_WG_SIZE
#else
#define BLOCK_SIZE 16
#endif

#define STR_SIZE 256
#define EXPAND_RATE 2		// add one iteration will extend the pyramid base by 2 per each borderline

/* maximum power density possible (say 300W for a 10mm x 10mm chip)	*/
#define MAX_PD	(3.0e6)
/* required precision in degrees	*/
#define PRECISION	0.001
#define SPEC_HEAT_SI 1.75e6
#define K_SI 100
/* capacitance fitting factor	*/
#define FACTOR_CHIP	0.5

/* chip parameters	*/
const static float t_chip = 0.0005;
const static float chip_height = 0.016;
const static float chip_width = 0.016;

// OpenCL globals
cl_context context;
cl_command_queue command_queue;
cl_device_id device;
cl_kernel kernel;

/*
  compute N time steps
*/

int compute_tran_temp(cl_mem MatrixPower, cl_mem MatrixTemp[2], int col,
		      int row, int total_iterations, int num_iterations,
		      int blockCols, int blockRows, int borderCols,
		      int borderRows, float *TempCPU, float *PowerCPU) {

  float grid_height = chip_height / row;
  float grid_width = chip_width / col;

  float Cap = FACTOR_CHIP * SPEC_HEAT_SI * t_chip * grid_width * grid_height;
  float Rx = grid_width / (2.0 * K_SI * t_chip * grid_height);
  float Ry = grid_height / (2.0 * K_SI * t_chip * grid_width);
  float Rz = t_chip / (K_SI * grid_height * grid_width);

  float max_slope = MAX_PD / (FACTOR_CHIP * t_chip * SPEC_HEAT_SI);
  float step = PRECISION / max_slope;
  int t;

  int src = 0, dst = 1;

  cl_int error;

  // Determine GPU work group grid
  size_t global_work_size[2];
  global_work_size[0] = BLOCK_SIZE * blockCols;
  global_work_size[1] = BLOCK_SIZE * blockRows;
  size_t local_work_size[2];
  local_work_size[0] = BLOCK_SIZE;
  local_work_size[1] = BLOCK_SIZE;

  for (t = 0; t < total_iterations; t += num_iterations) {

    // Specify kernel arguments
    int iter = MIN(num_iterations, total_iterations - t);
    clSetKernelArg(kernel, 0, sizeof(int), (void *)&iter);
    clSetKernelArg(kernel, 1, sizeof(cl_mem), (void *)&MatrixPower);
    clSetKernelArg(kernel, 2, sizeof(cl_mem), (void *)&MatrixTemp[src]);
    clSetKernelArg(kernel, 3, sizeof(cl_mem), (void *)&MatrixTemp[dst]);
    clSetKernelArg(kernel, 4, sizeof(int), (void *)&col);
    clSetKernelArg(kernel, 5, sizeof(int), (void *)&row);
    clSetKernelArg(kernel, 6, sizeof(int), (void *)&borderCols);
    clSetKernelArg(kernel, 7, sizeof(int), (void *)&borderRows);
    clSetKernelArg(kernel, 8, sizeof(float), (void *)&Cap);
    clSetKernelArg(kernel, 9, sizeof(float), (void *)&Rx);
    clSetKernelArg(kernel, 10, sizeof(float), (void *)&Ry);
    clSetKernelArg(kernel, 11, sizeof(float), (void *)&Rz);
    clSetKernelArg(kernel, 12, sizeof(float), (void *)&step);

    // Launch kernel
    error =
      clEnqueueNDRangeKernel(command_queue, kernel, 2, NULL,
                             global_work_size, local_work_size, 0, NULL,
                             NULL);
    if (error != CL_SUCCESS)
      fatal_CL(error, __LINE__);

    // Flush the queue
    error = clFlush(command_queue);
    if (error != CL_SUCCESS)
      fatal_CL(error, __LINE__);

    // Swap input and output GPU matrices
    src = 1 - src;
    dst = 1 - dst;
  }

  // Wait for all operations to finish
  error = clFinish(command_queue);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  return src;
}

void usage(int argc, char **argv) {
  fprintf(stderr,
          "Usage: %s <grid_rows/grid_cols> <pyramid_height> <sim_time> <runs>\n",
          argv[0]);
  fprintf(stderr,
          "\t<grid_rows/grid_cols>  - number of rows/cols in the grid (positive integer)\n");
  fprintf(stderr, "\t<pyramid_height> - pyramid heigh(positive integer)\n");
  fprintf(stderr, "\t<sim_time>   - number of iterations\n");
  fprintf(stderr, "\t<runs> - the number of benchmark runs to use\n");
  exit(1);
}

int main(int argc, char **argv) {
  stopwatch sw;
  int runs = 10;

  fprintf(stderr, "WG size of kernel = %d X %d\n", BLOCK_SIZE, BLOCK_SIZE);

  cl_int error;
  cl_uint num_platforms;

  // Get the number of platforms
  error = clGetPlatformIDs(0, NULL, &num_platforms);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  // Get the list of platforms
  cl_platform_id *platforms =
    (cl_platform_id *) malloc(sizeof(cl_platform_id) * num_platforms);
  error = clGetPlatformIDs(num_platforms, platforms, NULL);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  // Print the chosen platform (if there are multiple platforms, choose the first one)
  cl_platform_id platform = platforms[0];
  char pbuf[100];
  error =
    clGetPlatformInfo(platform, CL_PLATFORM_VENDOR, sizeof(pbuf), pbuf,
                      NULL);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);
  fprintf(stderr, "Platform: %s\n", pbuf);

  // Create a GPU context
  cl_context_properties context_properties[3] =
    { CL_CONTEXT_PLATFORM, (cl_context_properties) platform, 0 };
  context =
    clCreateContextFromType(context_properties, CL_DEVICE_TYPE_GPU, NULL,
                            NULL, &error);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  // Get and print the chosen device (if there are multiple devices, choose the first one)
  size_t devices_size;
  error =
    clGetContextInfo(context, CL_CONTEXT_DEVICES, 0, NULL, &devices_size);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);
  cl_device_id *devices = (cl_device_id *) malloc(devices_size);
  error =
    clGetContextInfo(context, CL_CONTEXT_DEVICES, devices_size, devices,
                     NULL);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);
  device = devices[0];
  error = clGetDeviceInfo(device, CL_DEVICE_NAME, sizeof(pbuf), pbuf, NULL);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);
  fprintf(stderr, "Device: %s\n", pbuf);

  // Create a command queue
  command_queue = clCreateCommandQueue(context, device, 0, &error);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  int size;
  int grid_rows, grid_cols = 0;
  float *FilesavingTemp, *FilesavingPower;	//,*MatrixOut;

  int total_iterations = 60;
  int pyramid_height = 1;	// number of iterations

  if (argc < 5)
    usage(argc, argv);
  if ((grid_rows = atoi(argv[1])) <= 0 ||
      (grid_cols = atoi(argv[1])) <= 0 ||
      (pyramid_height = atoi(argv[2])) <= 0 ||
      (total_iterations = atoi(argv[3])) <= 0 ||
      (runs = atoi(argv[4])) <= 0)
    usage(argc, argv);

  size = grid_rows * grid_cols;

  // --------------- pyramid parameters ---------------
  int borderCols = (pyramid_height) * EXPAND_RATE / 2;
  int borderRows = (pyramid_height) * EXPAND_RATE / 2;
  int smallBlockCol = BLOCK_SIZE - (pyramid_height) * EXPAND_RATE;
  int smallBlockRow = BLOCK_SIZE - (pyramid_height) * EXPAND_RATE;
  int blockCols =
    grid_cols / smallBlockCol + ((grid_cols % smallBlockCol == 0) ? 0 : 1);
  int blockRows =
    grid_rows / smallBlockRow + ((grid_rows % smallBlockRow == 0) ? 0 : 1);

  FilesavingTemp = (float *)malloc(size * sizeof(float));
  FilesavingPower = (float *)malloc(size * sizeof(float));
  // MatrixOut = (float *) calloc (size, sizeof(float));

  if (!FilesavingPower || !FilesavingTemp)	// || !MatrixOut)
    fatal("unable to allocate memory");

  srand(7);

  // Populate input data
  for (long int i = 0; i < grid_rows - 1; i++) {
    for (long int j = 0; j < grid_cols - 1; j++) {
      FilesavingTemp[i * grid_cols + j] = (float)rand()/(float)(RAND_MAX/10.0) + 1.0;
      FilesavingPower[i * grid_cols + j] = (float)rand()/(float)(RAND_MAX/10.0) + 1.0;
    }
  }

  // Load kernel source from file
  const char *source = load_kernel_source("hotspot_kernel.cl");
  size_t sourceSize = strlen(source);

  // Compile the kernel
  cl_program program =
    clCreateProgramWithSource(context, 1, &source, &sourceSize, &error);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  char clOptions[110];
  //  sprintf(clOptions,"-I../../src");
  sprintf(clOptions, " ");
#ifdef BLOCK_SIZE
  sprintf(clOptions + strlen(clOptions), " -DBLOCK_SIZE=%d", BLOCK_SIZE);
#endif

  // Create an executable from the kernel
  error = clBuildProgram(program, 1, &device, clOptions, NULL, NULL);
  // Show compiler warnings/errors
  static char log[65536];
  memset(log, 0, sizeof(log));
  clGetProgramBuildInfo(program, device, CL_PROGRAM_BUILD_LOG,
                        sizeof(log) - 1, log, NULL);
  if (strstr(log, "warning:") || strstr(log, "error:"))
    fprintf(stderr, "<<<<\n%s\n>>>>\n", log);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);
  kernel = clCreateKernel(program, "hotspot", &error);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  float* out_buf = malloc(sizeof(float) * size);

  // Create two temperature matrices and copy the temperature input data
  cl_mem MatrixTemp[2];
  // Create input memory buffers on device
  MatrixTemp[0] =
    clCreateBuffer(context, CL_MEM_READ_WRITE,
                   sizeof(float) * size, NULL, &error);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  // Lingjie Zhang modifited at Nov 1, 2015
  //MatrixTemp[1] = clCreateBuffer(context, CL_MEM_READ_WRITE | CL_MEM_ALLOC_HOST_PTR, sizeof(float) * size, NULL, &error);
  MatrixTemp[1] =
    clCreateBuffer(context, CL_MEM_READ_WRITE, sizeof(float) * size, NULL,
                   &error);
  // end Lingjie Zhang modification

  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  // Copy the power input data
  cl_mem MatrixPower =
    clCreateBuffer(context, CL_MEM_READ_ONLY,
                   sizeof(float) * size, NULL, &error);
  if (error != CL_SUCCESS)
    fatal_CL(error, __LINE__);

  for (int i = 0; i<runs+1; i++) {

    error = clEnqueueWriteBuffer(command_queue, MatrixTemp[0], 1, 0, sizeof(float) * size, FilesavingTemp, 0, 0, 0);
    if (error != CL_SUCCESS)
      fatal_CL(error, __LINE__);

    error = clEnqueueWriteBuffer(command_queue, MatrixPower, 1, 0, sizeof(float) * size, FilesavingPower, 0, 0, 0);
    if (error != CL_SUCCESS)
      fatal_CL(error, __LINE__);

    clFinish(command_queue);

    stopwatch_start(&sw);

    // Perform the computation
    int ret =
      compute_tran_temp(MatrixPower, MatrixTemp, grid_cols, grid_rows,
                        total_iterations, pyramid_height,
                        blockCols, blockRows, borderCols, borderRows,
                        FilesavingTemp, FilesavingPower);

    stopwatch_stop(&sw);

    if (runs != 0)
      printf("%ld\n", get_interval_by_usec(&sw));

    error = clEnqueueReadBuffer(command_queue, MatrixTemp[ret], 1, 0, sizeof(float) * size, out_buf, 0, 0, 0);
    if (error != CL_SUCCESS)
      fatal_CL(error, __LINE__);

  }

  free(out_buf);

  clReleaseMemObject(MatrixTemp[0]);
  clReleaseMemObject(MatrixTemp[1]);
  clReleaseMemObject(MatrixPower);

  clReleaseContext(context);

  return 0;
}
