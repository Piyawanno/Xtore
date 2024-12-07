from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.RecordNode cimport RecordNode

cdef class BasicStorage:
	cdef i64 create(self):
		raise NotImplementedError

	cdef RecordNode createNode(self):
		raise NotImplementedError

	cdef writeHeader(self):
		raise NotImplementedError

	cdef writeHeaderBuffer(self, Buffer *stream):
		raise NotImplementedError
		
	cdef readHeader(self, i64 rootPosition):
		raise NotImplementedError
		
	cdef readHeaderBuffer(self, Buffer *stream):
		raise NotImplementedError
		
	cdef setHeaderSize(self, i32 headerSize):
		raise NotImplementedError
		
	cdef setName(self, str name):
		raise NotImplementedError

	cdef RecordNode get(self, RecordNode reference, RecordNode result):
		raise NotImplementedError

	cdef set(self, RecordNode reference):
		raise NotImplementedError

	cdef appendNode(self, RecordNode node):
		raise NotImplementedError
		
	cdef RecordNode readNodeKey(self, i64 position, RecordNode node):
		raise NotImplementedError
		
	cdef readNodeValue(self, RecordNode node):
		raise NotImplementedError
		
	cdef writeNode(self, RecordNode node):
		raise NotImplementedError
		