from xtore.instance.HashStorage cimport HashStorage
from xtore.common.Buffer cimport Buffer

cdef class PeopleHashStorage(HashStorage):
	cdef Buffer entryStream