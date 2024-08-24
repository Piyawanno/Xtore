from xtore.instance.HashStorage cimport HashStorage
from xtore.common.Buffer cimport Buffer

cdef class PeopleStorage(HashStorage):
	cdef Buffer entryStream