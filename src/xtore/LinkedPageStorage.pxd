from xtore.BaseType cimport i32, i64
from xtore.Buffer cimport Buffer
from xtore.StreamIOHandler cimport StreamIOHandler
from xtore.LinkedPage cimport LinkedPage

cdef class LinkedPageStorage:
	cdef StreamIOHandler io
	cdef LinkedPage tail
	cdef i32 pageSize
	cdef i32 itemSize
	cdef i64 rootPosition
	cdef i64 tailPosition

	cdef Buffer headerStream

	cdef i64 create(self)
	cdef writeHeader(self)
	cdef readHeader(self, i64 rootPosition)

	cdef appendBuffer(self, Buffer *stream)
	cdef appendValue(self, char *value)
	cdef createPage(self)
