from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.BasicIterator cimport BasicIterator

cdef class BasicStorage:
	cdef StreamIOHandler io
	cdef str name
	cdef CollisionMode mode
	cdef i32 headerSize

	cdef i64 create(self)
	cdef RecordNode createNode(self)
	cdef writeHeader(self)
	cdef writeHeaderBuffer(self, Buffer *stream)
	cdef readHeader(self, i64 rootPosition)
	cdef readHeaderBuffer(self, Buffer *stream)
	cdef setHeaderSize(self, i32 headerSize)
	cdef setName(self, str name)

	cdef RecordNode get(self, RecordNode reference, RecordNode result)
	cdef set(self, RecordNode reference)

	cdef appendNode(self, RecordNode node)
	cdef RecordNode readNodeKey(self, i64 position, RecordNode node)
	cdef readNodeValue(self, RecordNode node)
	cdef writeNode(self, RecordNode node)

	cdef BasicIterator createIterator(self)