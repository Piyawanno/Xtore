from xtore.BaseType cimport i32, i64, f64
from xtore.common.Buffer cimport Buffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.LinkedPage cimport LinkedPage

cdef class LinkedPageStorage:
	cdef StreamIOHandler io
	cdef LinkedPage tail
	cdef i32 pageSize
	cdef i32 itemSize
	cdef i64 rootPosition
	cdef i64 tailPosition
	cdef i64 headPosition
	cdef f64 lastUpdate

	cdef Buffer headerStream

	cdef i64 create(self)
	cdef writeHeader(self)
	cdef readHeader(self, i64 rootPosition)

	cdef appendBuffer(self, Buffer *stream)
	cdef appendValue(self, char *value)
	cdef createPage(self)
