from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64

cdef class StreamIOHandler:
	cdef str path
	cdef i64 tail
	cdef object file
	cdef int fd

	cdef open(self)
	cdef close(self)
	cdef i64 reserve(self, int size)
	cdef seek(self, i64 position)
	cdef read(self, Buffer *stream, int size)
	cdef write(self, Buffer *stream)
	cdef writeOffset(self, Buffer *stream, i32 offset, i32 size)
	cdef i64 append(self, Buffer *stream)
	cdef i64 fill(self, Buffer *stream)
	cdef i64 getTail(self)
