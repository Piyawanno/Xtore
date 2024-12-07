from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.LinkedPageIterator cimport LinkedPageIterator


cdef class HashIterator:
	cdef HashStorage storage
	cdef LinkedPageIterator iterator
	cdef char *buffer

	cdef start(self)
	cdef bint getNext(self, RecordNode node)
