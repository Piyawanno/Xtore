from xtore.BaseType cimport i32, i64
from xtore.instance.Page cimport Page

cdef i32 LINKED_PAGE_HEADER_SIZE

cdef class LinkedPage (Page):
	cdef i64 next
	cdef i64 previous