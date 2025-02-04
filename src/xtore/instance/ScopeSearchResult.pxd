from xtore.BaseType cimport i32, u64
from xtore.instance.ScopeIterator cimport ScopeIterator

cdef class ScopeSearchResult (ScopeIterator):
	cdef u64 endPage
	cdef i32 endIndex