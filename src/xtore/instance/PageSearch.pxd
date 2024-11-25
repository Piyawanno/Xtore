from xtore.instance.Page cimport Page
from xtore.instance.LinkedPage cimport LinkedPage
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64, f64

# NOTE
# -1 : reference <  comparee
#  0 : reference == comparee
#  1 : reference >  comparee
ctypedef int (* BufferComparator) (Buffer *reference, Buffer *comparee)

ctypedef struct TopLayerPage:
	i64 position
	i64 previous
	i64 next
	i32 n
	Buffer head
	Buffer tail

cdef inline bint isPageChanged(LinkedPage page, TopLayerPage top):
	if page.position != top.position: return True
	if page.previous != top.previous: return True
	if page.next != top.next: return True
	if page.n != top.n: return True
	return False

cdef class PageSearch:
	cdef Page page

	cdef BufferComparator compare
	cdef TopLayerPage *topLayer
	cdef f64 lastTopLayerRead
	cdef i64 currentStoragePostition
	cdef i32 topLayerCount
	cdef i32 topLayerSize
	cdef char **topLayerBuffer
	cdef i32 topLayerBufferCount

	cdef i32 *position
	cdef i32 positionSize

	cdef Buffer stream

	cdef setPage(self, Page page)
	cdef readPosition(self, i64 storagePosition, f64 lastUpdate)
	cdef setTopLayerBuffer(self, i32 startPosition)
	
	cdef LinkedPage getPageInRange(self, Buffer *reference)
	cdef i32 getGreaterPage(self, Buffer *reference)
	cdef i32 getLessPage(self, Buffer *reference)
	cdef i32 getGreaterEqualPage(self, Buffer *reference)
	cdef i32 getLessEqualPage(self, Buffer *reference)

	cdef bint isUpperInRange(self, Buffer *reference, i32 index)
	# NOTE reference is less than header
	cdef bint isUpperLess(self, Buffer *reference, i32 index)
	# NOTE reference is greater than tail
	cdef bint isUpperGreater(self, Buffer *reference, i32 index)

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
