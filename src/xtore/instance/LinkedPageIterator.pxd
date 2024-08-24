from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32

cdef class LinkedPageIterator:
	cdef LinkedPageStorage storage
	cdef LinkedPage current
	cdef i32 currentPosition

	cdef start(self)
	cdef bint getNextBuffer(self, Buffer *stream)
	cdef bint getNextValue(self, char *buffer)