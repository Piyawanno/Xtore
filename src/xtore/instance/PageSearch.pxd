from xtore.instance.Page cimport Page
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64

# NOTE
# -1 : reference <  comparee
#  0 : reference == comparee
#  1 : reference >  comparee
ctypedef int (* BufferComparator) (Buffer *reference, Buffer *comparee)

cdef class PageSearch:
	cdef Page page

	cdef BufferComparator compare
	cdef i64 *pagePosition
	cdef i32 pagePositionCount
	cdef i32 pagePositionSize

	cdef i32 *position
	cdef i32 positionSize

	cdef Buffer stream

	cdef setPage(self, Page page)
	cdef readPosition(self)
	
	cdef LinkedPage getPageInRange(self, Buffer *reference)
	cdef i32 getGreaterPage(self, Buffer *reference)
	cdef i32 getLessPage(self, Buffer *reference)
	cdef i32 getGreaterEqualPage(self, Buffer *reference)
	cdef i32 getLessEqualPage(self, Buffer *reference)

	cdef bint isInRange(self, Buffer *reference)
	# NOTE reference is less than header
	cdef bint isLess(self, Buffer *reference)
	# NOTE reference is greater than tail
	cdef bint isGreater(self, Buffer *reference)

	cdef i32 getEqual(self, Buffer *reference)
	cdef i32 getGreater(self, Buffer *reference)
	cdef i32 getLess(self, Buffer *reference)
	cdef i32 getGreaterEqual(self, Buffer *reference)
	cdef i32 getLessEqual(self, Buffer *reference)
	cdef i32 search(self, Buffer *reference, bint *isFound)
	cdef i32 searchPage(self, Buffer *reference, bint *isFound)
