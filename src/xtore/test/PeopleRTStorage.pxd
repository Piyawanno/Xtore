from xtore.instance.ScopeTreeStorage cimport ScopeTreeStorage
from xtore.common.Buffer cimport Buffer

cdef class PeopleRTStorage(ScopeTreeStorage):
	cdef Buffer entryStream
