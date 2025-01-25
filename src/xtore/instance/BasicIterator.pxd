from xtore.instance.RecordNode cimport RecordNode

cdef class BasicIterator:
	cdef start(self)
	cdef bint getNext(self, RecordNode node)