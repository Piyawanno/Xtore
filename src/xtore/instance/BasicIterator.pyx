from xtore.instance.RecordNode cimport RecordNode

cdef class BasicIterator:
	cdef start(self):
		raise NotImplementedError

	cdef bint getNext(self, RecordNode node):
		raise NotImplementedError