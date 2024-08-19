from xtore.common.Buffer cimport Buffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.HashNode cimport HashNode
from xtore.BaseType cimport i32, i64

cdef i32 HASH_LAYER

cdef class HashStorage:
	cdef i64 rootPosition
	cdef i32 layer
	cdef i32 headerSize
	cdef Buffer stream
	cdef Buffer headerStream
	cdef Buffer pageStream
	cdef StreamIOHandler io
	cdef i64 position
	cdef i64* layerModulus
	cdef i64* layerSize
	cdef i64* layerPosition

	cdef i64 create(self)
	cdef writeHeader(self)
	cdef readHeader(self, i64 rootPosition)
	
	cdef HashNode get(self, HashNode reference)
	cdef set(self, HashNode reference)

	cdef HashNode getBucket(self, i64 hashed, HashNode reference)
	cdef bint setBucket(self, i64 hashed, HashNode node)
	cdef i64 setTreeRoot(self, i64 hashed, HashNode node)
	cdef setTree(self, i64 hashed, HashNode node)
	cdef setTreePage(self, i64 hashed, HashNode node)
	cdef createTreePage(self)
	cdef HashNode getTree(self, i64 hashed, HashNode reference, i64 rootPosition)
	cdef HashNode getTreePage(self, i64 hashed, HashNode reference)
	cdef bint checkTailSize(self)
	cdef expandLayer(self, i32 layer)
	cdef appendNode(self, HashNode node)
	cdef HashNode readNodeKey(self, i64 position)
	cdef readNodeValue(self, HashNode node)
	cdef writeNode(self, HashNode node)
