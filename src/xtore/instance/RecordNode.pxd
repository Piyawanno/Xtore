from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i16, i32, i64, u8, u32, f128

cdef inline i64 hashDJB(char *key, u32 klen):
	cdef i64 hashed = 5381
	for i in range(klen):
		hashed = ((hashed << 5) + hashed) + <u8> key[i]
	return hashed

cdef class RecordNode:
	cdef i64 position
	cdef i16 version

	cdef i64 hash(self)
	cdef bint isEqual(self, RecordNode other)
	cdef readKey(self, i16 version, Buffer *stream)
	cdef readValue(self, i16 version, Buffer *stream)
	cdef write(self, Buffer *stream)
	# NOTE
	# -1 : self <  other
	#  0 : self == other
	#  1 : self >  other
	cdef i32 compare(self, RecordNode other)
	cdef copyKey(self, RecordNode other)
	# NOTE For ScopeTreeStorage
	cdef f128 getRangeValue(self)
