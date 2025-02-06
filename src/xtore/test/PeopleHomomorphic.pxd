from xtore.instance.HomomorphicBSTStorage cimport HomomorphicBSTStorage
from xtore.common.Buffer cimport Buffer

cdef class PeopleHomomorphic(HomomorphicBSTStorage):
	cdef Buffer entryStream
