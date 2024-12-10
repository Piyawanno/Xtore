from xtore.instance.RangeTreeStorage cimport RangeTreeStorage
from xtore.common.Buffer cimport Buffer

cdef class PeopleRTStorage(RangeTreeStorage):
	cdef Buffer entryStream
