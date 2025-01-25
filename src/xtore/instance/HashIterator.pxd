from xtore.instance.BasicIterator cimport BasicIterator
from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.LinkedPageIterator cimport LinkedPageIterator


cdef class HashIterator (BasicIterator):
	cdef HashStorage storage
	cdef LinkedPageIterator iterator
	cdef char *buffer
