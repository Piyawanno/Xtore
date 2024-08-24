from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.HashNode cimport HashNode
from xtore.instance.LinkedPageIterator cimport LinkedPageIterator


cdef class HashIterator:
	cdef HashStorage storage
	cdef LinkedPageIterator iterator
	cdef char *buffer

	cdef start(self)
	cdef bint getNext(self, HashNode node)
