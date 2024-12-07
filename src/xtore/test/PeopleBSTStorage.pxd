from xtore.instance.BinarySearchTreeStorage cimport BinarySearchTreeStorage
from xtore.common.Buffer cimport Buffer

cdef class PeopleBSTStorage(BinarySearchTreeStorage):
	cdef Buffer entryStream
