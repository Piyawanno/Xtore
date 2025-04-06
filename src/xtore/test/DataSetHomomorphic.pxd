from xtore.instance.HomomorphicBSTStorage cimport HomomorphicBSTStorage
from xtore.common.Buffer cimport Buffer
from libc.stdlib cimport malloc

cdef class DataSetHomomorphic(HomomorphicBSTStorage):
	cdef Buffer entryStream
