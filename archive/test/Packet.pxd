from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i16, i32, u64
from xtore.instance.RecordNode cimport RecordNode

cdef i32 BUFFER_SIZE = 1 << 16

ctypedef enum DatabaseOperation:
	SET = 10
	GET = 20

ctypedef enum InstanceType:
	HASH = 10

cdef class Packet:
	cdef DatabaseOperation operation
	cdef InstanceType type
	cdef str tableName
	cdef i16 version

	cdef dict[str, object] classMapper

	cdef u64 ID
	cdef str header
	cdef str data

	cdef registerClass(self, str tableName, object recordClass)
	cdef code(self, Buffer *stream, str tableName, list[RecordNode] recordList)
	cdef list[RecordNode] decode(self, Buffer *stream)
	

	cdef readKey(self, Buffer *stream)
	cdef readValue(self, Buffer *stream)
	cdef write(self, Buffer *stream)
	cdef getHeader(self)
	cdef u64 hash(self, Buffer *stream)
	# NOTE
	#  0 : self == other (same)
	#  1 : self !=  other (different)
	cdef i32 compareHash(self, u64 hashStream)