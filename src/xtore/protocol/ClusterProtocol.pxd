from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i16, i32, u64
from xtore.instance.RecordNode cimport RecordNode
from xtore.protocol.AsyncProtocol cimport AsyncProtocol

cdef i32 BUFFER_SIZE = 1 << 16

ctypedef enum DatabaseOperation:
	SET = 10
	GET = 20

ctypedef enum InstanceType:
	HASH = 10

cdef class ClusterProtocol (AsyncProtocol):
	cdef DatabaseOperation operation
	cdef InstanceType type
	cdef str tableName
	cdef i16 version
	cdef i32 recordCount

	cdef dict[str, object] classMapper
	cdef Buffer stream

	cdef registerClass(self, str tableName, object recordClass)
	cdef code(self, Buffer *stream, list[RecordNode] recordList)
	cdef list[RecordNode] decode(self, Buffer *stream)
	cdef getHeader(self, Buffer *stream)