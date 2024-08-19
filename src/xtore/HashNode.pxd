from xtore.Buffer cimport Buffer
from xtore.BaseType cimport i16, i64, u8, u32

cdef i64 hashDJB(char *key, u32 klen):
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
