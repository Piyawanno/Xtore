from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, u64

cdef i32 BUFFER_SIZE = 1 << 16

cdef class Package:
	cdef u64 ID
	cdef str header
	cdef str data

	cdef readKey(self, Buffer *stream)
	cdef readValue(self, Buffer *stream)
	cdef write(self, Buffer *stream)
	cdef getHeader(self)
	cdef u64 hash(self, Buffer *stream)
	# NOTE
	#  0 : self == other (same)
	#  1 : self !=  other (different)
	cdef i32 compareHash(self, u64 hashStream)