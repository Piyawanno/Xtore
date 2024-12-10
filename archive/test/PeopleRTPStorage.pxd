from xtore.instance.RangeTreePlusStorage cimport RangeTreePlusStorage
from xtore.common.Buffer cimport Buffer

cdef class PeopleRTPStorage(RangeTreePlusStorage):
	cdef Buffer entryStream
