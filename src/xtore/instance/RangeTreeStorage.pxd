from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.RecordNode cimport RecordNode
from xtore.common.StreamIOHandler cimport StreamIOHandler


cdef class RangeTreeStorage:
	cdef StreamIOHandler io
	cdef str name
	cdef CollisionMode mode
	cdef i64 rootPosition

	cdef Buffer headerStream

	cdef i64 create(self)
	cdef RecordNode createNode(self)
	cdef writeHeader(self)
	cdef writeHeaderBuffer(self, Buffer *stream)
	cdef readHeader(self, i64 rootPosition)
	cdef readHeaderBuffer(self, Buffer *stream)
	cdef setHeaderSize(self, i32 headerSize)
	cdef setName(self, str name)
