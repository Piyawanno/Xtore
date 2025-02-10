from xtore.BaseType cimport i32, u64

cdef class PrimeRingMinus:
	cdef list layers
	cdef list nodes
	cdef i32 numLayers
	cdef list primeNumbers
	cdef i32 maxNodeLayer

	cdef u64 getNode(self, u64 key)
	cdef u64 getIndex(self, u64 key, i32 layer)
	cdef insertNode(self, dict info)
	cdef insertLayer(self)

