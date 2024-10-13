from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer
from xtore.common.StreamIOHandler cimport StreamIOHandler

cdef i32 PAGE_HEADER_SIZE

cdef class Page:
	cdef i32 headerSize
	cdef i64 position
	cdef i32 tail
	cdef i32 pageSize
	cdef i32 itemSize
	cdef i32 n
	cdef StreamIOHandler io
	cdef Buffer stream
	cdef bint hasBody

	cdef reset(self)
	cdef i64 create(self)
	cdef copyHeader(self, Page other)
	cdef i32 getCapacity(self)
	
	cdef bint appendBuffer(self, Buffer *stream)
	cdef bint appendValue(self, char *value)
	cdef bint writeValue(self, char *value, i32 index)

	cdef read(self, i64 position)
	cdef readHeader(self, i64 position)
	cdef readHeaderBuffer(self)
	cdef write(self)
	cdef writeHeader(self)
	cdef writeHeaderBuffer(self)

	cdef startIteration(self)
	cdef bint hasNext(self)
	cdef i32 getNext(self)