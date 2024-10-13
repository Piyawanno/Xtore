from xtore.common.Buffer cimport Buffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.LinkedPageStorage cimport LinkedPageStorage
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.instance.HashNode cimport HashNode
from xtore.BaseType cimport i32, i64, f64

cdef i32 HASH_LAYER

cdef class HashStorage:
	cdef i64 rootPosition
	cdef i64 treePosition
	cdef i64 pagePosition
	cdef f64 lastUpdate
	cdef i32 layer
	cdef i32 headerSize
	cdef i32 n
	cdef CollisionMode mode
	cdef LinkedPageStorage pageStorage
	cdef HashNode comparingNode
	cdef Buffer stream
	cdef Buffer headerStream
	cdef Buffer pageStream
	cdef StreamIOHandler io
	cdef i64 position
	cdef i64* layerModulus
	cdef i64* layerSize
	cdef i64* layerPosition
	cdef bint isIterable
	cdef bint isCreated

	cdef enableIterable(self)
	cdef i64 create(self)
	cdef HashNode createNode(self)
	cdef writeHeader(self)
	cdef writeHeaderBuffer(self, Buffer *stream)
	cdef readHeader(self, i64 rootPosition)
	cdef readHeaderBuffer(self, Buffer *stream)
	
	cdef HashNode get(self, HashNode reference, HashNode result)
	cdef set(self, HashNode reference)
	cdef setComparingNode(self, HashNode comparingNode)

	cdef HashNode getBucket(self, i64 hashed, HashNode reference, HashNode result)
	cdef int setBucket(self, i64 hashed, HashNode node)
	cdef i64 setTreeRoot(self, i64 hashed, HashNode node)
	cdef int setTree(self, i64 hashed, HashNode node, i64 rootPosition)
	cdef int setTreePage(self, i64 hashed, HashNode node)
	cdef createTreePage(self)
	cdef HashNode getTree(self, i64 hashed, HashNode reference, HashNode result, i64 rootPosition)
	cdef HashNode getTreePage(self, i64 hashed, HashNode reference, HashNode result)
	cdef bint checkTailSize(self)
	cdef expandLayer(self, i32 layer)
	cdef appendNode(self, HashNode node)
	cdef HashNode readNodeKey(self, i64 position, HashNode node)
	cdef readNodeValue(self, HashNode node)
	cdef writeNode(self, HashNode node)
