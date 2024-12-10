from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i16, i64

cdef class RecordNodeKey:
	pass

cdef class RecordNode:
	def __init__(self):
		self.position = -1

	cdef i64 hash(self):
		raise NotImplementedError

	cdef bint isEqual(self, RecordNode other):
		raise NotImplementedError

	cdef readKey(self, i16 version, Buffer *stream):
		raise NotImplementedError

	cdef readValue(self, i16 version, Buffer *stream):
		raise NotImplementedError

	cdef write(self, Buffer *stream):
		raise NotImplementedError
	
	cdef i32 compare(self, RecordNode other):
		raise NotImplementedError
	
	cdef copyKey(self, RecordNode other):
		raise NotImplementedError

	cdef f128 getRangeValue(self):
		raise NotImplementedError