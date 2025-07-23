// Copyright © 2019-2023
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <vx_print.h>
#include <vx_spawn.h>
#include <vx_intrinsics.h>
#include <vx_utils.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "tinyprintf.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
	const char* format;
	va_list*    va;
	int         ret;
} printf_arg_t;

typedef struct {
	int value;
	int base;
} putint_arg_t;

typedef struct {
	float value;
	int precision;
} putfloat_arg_t;

static void __vprintf_cb(printf_arg_t* arg) {
	arg->ret = tiny_vprintf(arg->format, *arg->va);
}

int vx_vprintf(const char* format, va_list va) {
	printf_arg_t arg;
	arg.format = format;
	arg.va = &va;
	vx_serial((vx_serial_cb)__vprintf_cb, &arg);
  	return arg.ret;
}

int vx_printf(const char * format, ...) {
	int ret;
	va_list va;
	va_start(va, format);
	ret = vx_vprintf(format, va);
	va_end(va);		
  	return ret;
}

#ifdef __cplusplus
}
#endif
