from xtore.common.Buffer cimport Buffer
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.BaseType cimport i32, i64, f64

cdef i32 HASH_LAYER

cdef class HashStorage (BasicStorage):
	cdef i64 rootPosition
	cdef i64 treePosition
	cdef i64 pagePosition
	cdef f64 lastUpdate
	cdef i32 layer
	cdef i32 n
	cdef LinkedPageStorage pageStorage
	cdef RecordNode comparingNode
	cdef Buffer stream
	cdef Buffer headerStream
	cdef Buffer pageStream
	cdef i64 position
	cdef i64* layerModulus
	cdef i64* layerSize
	cdef i64* layerPosition
	cdef bint isIterable
	cdef bint isCreated

	cdef enableIterable(self)
	cdef setComparingNode(self, RecordNode comparingNode)

	cdef RecordNode getBucket(self, i64 hashed, RecordNode reference, RecordNode result)
	cdef int setBucket(self, i64 hashed, RecordNode node)
	cdef i64 setTreeRoot(self, i64 hashed, RecordNode node)
	cdef int setTree(self, i64 hashed, RecordNode node, i64 rootPosition)
	cdef int setTreePage(self, i64 hashed, RecordNode node)
	cdef createTreePage(self)
	cdef RecordNode getTree(self, i64 hashed, RecordNode reference, RecordNode result, i64 rootPosition)
	cdef RecordNode getTreePage(self, i64 hashed, RecordNode reference, RecordNode result)
	cdef bint checkTailSize(self)
	cdef expandLayer(self, i32 layer)

