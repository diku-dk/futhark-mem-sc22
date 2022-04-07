/*
 * =====================================================================================
 *
 *       Filename:  lud.cu
 *
 *    Description:  The main wrapper for the suite
 *
 *        Version:  1.0
 *        Created:  10/22/2009 08:40:34 PM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  Liang Wang (lw2aw), lw2aw@virginia.edu
 *        Company:  CS@UVa
 *
 * =====================================================================================
 */

#include <stdio.h>
#include <unistd.h>
#include <getopt.h>
#include <stdlib.h>
#include <assert.h>

#include "common.h"
#include <sys/time.h>

#define CL_TARGET_OPENCL_VERSION 120
#define CL_USE_DEPRECATED_OPENCL_1_2_APIS

#include <CL/cl.h>

#include <string.h>
#include <string>
#ifdef RD_WG_SIZE_0_0
#define BLOCK_SIZE RD_WG_SIZE_0_0
#elif defined(RD_WG_SIZE_0)
#define BLOCK_SIZE RD_WG_SIZE_0
#elif defined(RD_WG_SIZE)
#define BLOCK_SIZE RD_WG_SIZE
#else
#define BLOCK_SIZE 16
#endif

double gettime() {
    struct timeval t;
    gettimeofday(&t, NULL);
    return t.tv_sec + t.tv_usec * 1e-6;
}

static cl_context context;
static cl_command_queue cmd_queue;
static cl_device_type device_type;
static cl_device_id *device_list;
static cl_int num_devices;

static int initialize(int use_gpu) {
    cl_int result;
    size_t size;

    // create OpenCL context
    cl_platform_id platform_id;
    if (clGetPlatformIDs(1, &platform_id, NULL) != CL_SUCCESS) {
        fprintf(stderr, "ERROR: clGetPlatformIDs(1,*,0) failed\n");
	return -1;
    }

    cl_context_properties ctxprop[] =
	{ CL_CONTEXT_PLATFORM, (cl_context_properties) platform_id, 0 };
    device_type = use_gpu ? CL_DEVICE_TYPE_GPU : CL_DEVICE_TYPE_CPU;
    context = clCreateContextFromType(ctxprop, device_type, NULL, NULL, NULL);
    if (!context) {
      fprintf(stderr, "ERROR: clCreateContextFromType(%s) failed\n",
	       use_gpu ? "GPU" : "CPU");
	return -1;
    }
    // get the list of GPUs
    result = clGetContextInfo(context, CL_CONTEXT_DEVICES, 0, NULL, &size);
    num_devices = (int)(size / sizeof(cl_device_id));
    fprintf(stderr, "num_devices = %d\n", num_devices);

    if (result != CL_SUCCESS || num_devices < 1) {
      fprintf(stderr, "ERROR: clGetContextInfo() failed\n");
	return -1;
    }
    device_list = new cl_device_id[num_devices];
    if (!device_list) {
      fprintf(stderr, "ERROR: new cl_device_id[] failed\n");
	return -1;
    }
    result =
	clGetContextInfo(context, CL_CONTEXT_DEVICES, size, device_list, NULL);
    if (result != CL_SUCCESS) {
      fprintf(stderr, "ERROR: clGetContextInfo() failed\n");
	return -1;
    }
    // create command queue for the first device
    cmd_queue = clCreateCommandQueue(context, device_list[0], 0, NULL);
    if (!cmd_queue) {
      fprintf(stderr, "ERROR: clCreateCommandQueue() failed\n");
	return -1;
    }
    return 0;
}

static int shutdown() {
    // release resources
    if (cmd_queue)
	clReleaseCommandQueue(cmd_queue);
    if (context)
	clReleaseContext(context);
    if (device_list)
	delete device_list;

    // reset all variables
    cmd_queue = 0;
    context = 0;
    device_list = 0;
    num_devices = 0;
    device_type = 0;

    return 0;
}

static int do_verify = 0;
void lud_cuda(float *d_m, int matrix_dim);

static struct option long_options[] = {
    /* name, has_arg, flag, val */
    {"input", 1, NULL, 'i'},
    {"size", 1, NULL, 's'},
    {"verify", 0, NULL, 'v'},
    {"runs", 1, NULL, 'r'},
    {0, 0, 0, 0}
};

int main(int argc, char *argv[]) {
    fprintf(stderr, "WG size of kernel = %d X %d\n", BLOCK_SIZE, BLOCK_SIZE);

    int matrix_dim = 32;	/* default matrix_dim */
    int opt, option_index = 0;
    func_ret_t ret;
    const char *input_file = NULL;
    float *m, *mm;
    stopwatch sw;
    int runs = 10;

    while ((opt = getopt_long(argc, argv, "::vs:i:r:",
			      long_options, &option_index)) != -1) {
	switch (opt) {
	case 'i':
	    input_file = optarg;
	    break;
	case 'v':
	    do_verify = 1;
	    break;
	case 's':
	    matrix_dim = atoi(optarg);
	    fprintf(stderr, "Generate input matrix internally, size =%d\n", matrix_dim);
	    break;
        case 'r':
            runs = atoi(optarg);
            break;
	case '?':
	    fprintf(stderr, "invalid option\n");
	    break;
	case ':':
	    fprintf(stderr, "missing argument\n");
	    break;
	default:
	    fprintf(stderr, "Usage: %s [-r runs] [-v] [-s matrix_size|-i input_file]\n",
		    argv[0]);
	    exit(EXIT_FAILURE);
	}
    }

    if ((optind < argc) || (optind == 1)) {
	fprintf(stderr, "Usage: %s [-v] [-s matrix_size|-i input_file]\n",
		argv[0]);
	exit(EXIT_FAILURE);
    }

    if (input_file) {
        fprintf(stderr, "Reading matrix from file %s\n", input_file);
	ret = create_matrix_from_file(&m, input_file, &matrix_dim);
	if (ret != RET_SUCCESS) {
	    m = NULL;
	    fprintf(stderr, "error create matrix from file %s\n", input_file);
	    exit(EXIT_FAILURE);
	}
    } else if (matrix_dim) {
        fprintf(stderr, "Creating matrix internally size=%d\n", matrix_dim);
	ret = create_matrix(&m, matrix_dim);
	if (ret != RET_SUCCESS) {
	    m = NULL;
	    fprintf(stderr, "error create matrix internally size=%d\n",
		    matrix_dim);
	    exit(EXIT_FAILURE);
	}
    } else {
        fprintf(stderr, "No input file specified!\n");
	exit(EXIT_FAILURE);
    }

    matrix_duplicate(m, &mm, matrix_dim);

    int sourcesize = 1024 * 1024;
    char *source = (char *)calloc(sourcesize, sizeof(char));
    if (!source) {
        fprintf(stderr, "ERROR: calloc(%d) failed\n", sourcesize);
	return -1;
    }

    const char *kernel_lud_diag = "lud_diagonal";
    const char *kernel_lud_peri = "lud_perimeter";
    const char *kernel_lud_inter = "lud_internal";
    FILE *fp = fopen("./lud_kernel.cl", "rb");
    if (!fp) {
        fprintf(stderr, "ERROR: unable to open ./lud_kernel.cl\n");
	return -1;
    }

    if (fread(source, sourcesize, 1, fp) < 0) {
      fprintf(stderr, "ERROR: couldn't read from ./lud_kernel.cl\n");
      return -1;
    }

    fclose(fp);

    // Use 1: GPU  0: CPU
    int use_gpu = 1;

    // OpenCL initialization
    if (initialize(use_gpu))
	return -1;

    // compile kernel
    cl_int err = 0;
    const char *slist[2] = { source, 0 };
    cl_program prog = clCreateProgramWithSource(context, 1, slist, NULL, &err);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "ERROR: clCreateProgramWithSource() => %d\n", err);
	return -1;
    }
    char clOptions[110];

    sprintf(clOptions, " ");
#ifdef BLOCK_SIZE
    sprintf(clOptions + strlen(clOptions), " -DBLOCK_SIZE=%d", BLOCK_SIZE);
#endif

    err = clBuildProgram(prog, 0, NULL, clOptions, NULL, NULL);

    if (err != CL_SUCCESS) {
        fprintf(stderr, "ERROR: clBuildProgram() => %d\n", err);
	return -1;
    }

    cl_kernel diagnal;
    cl_kernel perimeter;
    cl_kernel internal;
    diagnal = clCreateKernel(prog, kernel_lud_diag, &err);
    perimeter = clCreateKernel(prog, kernel_lud_peri, &err);
    internal = clCreateKernel(prog, kernel_lud_inter, &err);
    if (err != CL_SUCCESS) {
        fprintf(stderr, "ERROR: clCreateKernel() 0 => %d\n", err);
	return -1;
    }
    clReleaseProgram(prog);

    //size_t local_work[3] = { 1, 1, 1 };
    //size_t global_work[3] = {1, 1, 1 };

    cl_mem d_m;
    d_m =
	clCreateBuffer(context, CL_MEM_READ_WRITE,
		       matrix_dim * matrix_dim * sizeof(float), NULL, &err);
    if (err != CL_SUCCESS) {
      fprintf(stderr, "ERROR: clCreateBuffer d_m (size:%d) => %d\n",
	       matrix_dim * matrix_dim, err);
	return -1;
    }

    for (int run = 0; run < runs + 1; run++) {
	err =
	    clEnqueueWriteBuffer(cmd_queue, d_m, 1, 0,
				 matrix_dim * matrix_dim * sizeof(float), mm, 0,
				 0, 0);
	if (err != CL_SUCCESS) {
          fprintf(stderr, "ERROR: clEnqueueWriteBuffer d_m (size:%d) => %d\n",
		   matrix_dim * matrix_dim, err);
	    return -1;
	}

	/* beginning of timing point */
	stopwatch_start(&sw);

	int i = 0;
	for (i = 0; i < matrix_dim - BLOCK_SIZE; i += BLOCK_SIZE) {

	    clSetKernelArg(diagnal, 0, sizeof(void *), (void *)&d_m);
	    clSetKernelArg(diagnal, 1,
			   sizeof(float) * BLOCK_SIZE * BLOCK_SIZE,
			   (void *)NULL);
	    clSetKernelArg(diagnal, 2, sizeof(cl_int), (void *)&matrix_dim);
	    clSetKernelArg(diagnal, 3, sizeof(cl_int), (void *)&i);

	    size_t global_work1[3] = { BLOCK_SIZE, 1, 1 };
	    size_t local_work1[3] = { BLOCK_SIZE, 1, 1 };

	    err =
		clEnqueueNDRangeKernel(cmd_queue, diagnal, 2, NULL,
				       global_work1, local_work1, 0, 0, 0);
	    if (err != CL_SUCCESS) {
		fprintf
                    (stderr, "ERROR:  diagnal clEnqueueNDRangeKernel()=>%d failed\n",
		     err);
		return -1;
	    }

	    clSetKernelArg(perimeter, 0, sizeof(void *), (void *)&d_m);
	    clSetKernelArg(perimeter, 1,
			   sizeof(float) * BLOCK_SIZE * BLOCK_SIZE,
			   (void *)NULL);
	    clSetKernelArg(perimeter, 2,
			   sizeof(float) * BLOCK_SIZE * BLOCK_SIZE,
			   (void *)NULL);
	    clSetKernelArg(perimeter, 3,
			   sizeof(float) * BLOCK_SIZE * BLOCK_SIZE,
			   (void *)NULL);
	    clSetKernelArg(perimeter, 4, sizeof(cl_int), (void *)&matrix_dim);
	    clSetKernelArg(perimeter, 5, sizeof(cl_int), (void *)&i);

	    size_t global_work2[3] =
              { BLOCK_SIZE * 2 * (((size_t) matrix_dim - (size_t) i) / BLOCK_SIZE - 1),
                  1,
                  1
                };
	    size_t local_work2[3] = { BLOCK_SIZE * 2, 1, 1 };

	    err =
		clEnqueueNDRangeKernel(cmd_queue, perimeter, 2, NULL,
				       global_work2, local_work2, 0, 0, 0);
	    if (err != CL_SUCCESS) {
		fprintf
                    (stderr, "ERROR:  perimeter clEnqueueNDRangeKernel()=>%d failed\n",
		     err);
		return -1;
	    }

	    clSetKernelArg(internal, 0, sizeof(void *), (void *)&d_m);
	    clSetKernelArg(internal, 1,
			   sizeof(float) * BLOCK_SIZE * BLOCK_SIZE,
			   (void *)NULL);
	    clSetKernelArg(internal, 2, sizeof(float) * BLOCK_SIZE * BLOCK_SIZE,
			   (void *)NULL);
	    clSetKernelArg(internal, 3, sizeof(cl_int), (void *)&matrix_dim);
	    clSetKernelArg(internal, 4, sizeof(cl_int), (void *)&i);

	    size_t global_work3[3] =
              { BLOCK_SIZE * (((size_t) matrix_dim - (size_t) i) / BLOCK_SIZE - 1),
		BLOCK_SIZE * (((size_t) matrix_dim - (size_t) i) / BLOCK_SIZE - 1), 1
	    };
	    size_t local_work3[3] = { BLOCK_SIZE, BLOCK_SIZE, 1 };

	    err =
		clEnqueueNDRangeKernel(cmd_queue, internal, 2, NULL,
				       global_work3, local_work3, 0, 0, 0);
	    if (err != CL_SUCCESS) {
		fprintf
                    (stderr, "ERROR:  internal clEnqueueNDRangeKernel()=>%d failed\n",
		     err);
		return -1;
	    }
	}
	clSetKernelArg(diagnal, 0, sizeof(void *), (void *)&d_m);
	clSetKernelArg(diagnal, 1, sizeof(float) * BLOCK_SIZE * BLOCK_SIZE,
		       (void *)NULL);
	clSetKernelArg(diagnal, 2, sizeof(cl_int), (void *)&matrix_dim);
	clSetKernelArg(diagnal, 3, sizeof(cl_int), (void *)&i);

	size_t global_work1[3] = { BLOCK_SIZE, 1, 1 };
	size_t local_work1[3] = { BLOCK_SIZE, 1, 1 };
	err =
	    clEnqueueNDRangeKernel(cmd_queue, diagnal, 2, NULL, global_work1,
				   local_work1, 0, 0, 0);
	if (err != CL_SUCCESS) {
            fprintf(stderr, "ERROR:  diagnal clEnqueueNDRangeKernel()=>%d failed\n",
		   err);
	    return -1;
	}

	clFinish(cmd_queue);

	/* end of timing point */
	stopwatch_stop(&sw);

	err =
	    clEnqueueReadBuffer(cmd_queue, d_m, 1, 0,
				matrix_dim * matrix_dim * sizeof(float), m, 0,
				0, 0);

	if (err != CL_SUCCESS) {
            fprintf(stderr, "ERROR: clEnqueueReadBuffer  d_m (size:%d) => %d\n",
 		   matrix_dim * matrix_dim, err);
	    return -1;
	}

	if (run != 0) {
          printf("%ld\n", get_interval_by_usec(&sw));
	}
    }

    clReleaseMemObject(d_m);

    if (do_verify) {
	fprintf(stderr, ">>>Verify<<<<\n");
	lud_verify(mm, m, matrix_dim);
	free(mm);
    }

    free(m);

    if (shutdown())
	return -1;

}

/* ----------  end of function main  ---------- */
