from xtore.BaseType cimport f64
from posix.time cimport gettimeofday, timeval

cdef inline f64 getMicroTime():
	cdef timeval tv
	gettimeofday(&tv, NULL)
	cdef f64 timeStamp = tv.tv_sec + tv.tv_usec/1_000_000.0
	return timeStamp