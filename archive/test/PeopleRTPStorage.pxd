from xtore.instance.ScopeTreePlusStorage cimport ScopeTreePlusStorage
from xtore.common.Buffer cimport Buffer

cdef class PeopleRTPStorage(ScopeTreePlusStorage):
	cdef Buffer entryStream
