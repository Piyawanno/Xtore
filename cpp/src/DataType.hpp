#ifndef XUTIL_DATA_TYPE_H

#if defined(__linux__) || defined (__APPLE__)
#define XUTIL_DATA_TYPE_H
	typedef char i8;
	typedef short i16; 
	typedef int i32;
	typedef long i64;
	typedef float f32;
	typedef double f64;
	typedef long double f128;
	typedef unsigned char u8;
	typedef unsigned short u16; 
	typedef unsigned int u32;
	typedef unsigned long u64;
	typedef unsigned char byte;
#endif
#endif
