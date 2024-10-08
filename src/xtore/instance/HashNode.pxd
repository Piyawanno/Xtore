from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i16, i32, i64, u8, u32

cdef inline i64 hashDJB(char *key, u32 klen):
	cdef i64 hashed = 5381
	for i in range(klen):
		hashed = ((hashed << 5) + hashed) + <u8> key[i]
	return hashed

cdef class HashNode:
	cdef i64 position
	cdef i16 version

	cdef i64 hash(self)
	cdef bint isEqual(self, HashNode other)
	cdef readKey(self, i16 version, Buffer *stream)
	cdef readValue(self, i16 version, Buffer *stream)
	cdef write(self, Buffer *stream)
	# NOTE
	# -1 : self <  other
	#  0 : self == other
	#  1 : self >  other
	cdef i32 compare(self, HashNode other)
	cdef copyKey(self, HashNode other)
