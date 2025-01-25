from xtore.instance.HashStorage cimport HashStorage
from xtore.common.Buffer cimport Buffer

cdef class DataHashStorage(HashStorage):
	cdef Buffer entryStream