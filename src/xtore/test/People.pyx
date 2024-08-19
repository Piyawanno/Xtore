from xtore.HashNode cimport HashNode
from xtore.Buffer cimport Buffer, getBuffer
from xtore.BaseType cimport i16, i64, u64

cdef class People (HashNode):
	cdef i64 hash(self):
		return <i64> self.ID

	cdef bint isEqual(self, HashNode other):
		cdef People otherPeople = <People> other
		return self.ID == otherPeople.ID

	cdef readKey(self, i16 version, Buffer *stream):
		self.ID = (<i64*> getBuffer(stream, 8))[0]

	cdef readValue(self, i16 version, Buffer *stream):
		raise NotImplementedError

	cdef write(self, Buffer *stream):
		raise NotImplementedError