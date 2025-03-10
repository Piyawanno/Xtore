from xtore.common.Buffer cimport Buffer
from xtore.protocol.RecordNodeProtocol cimport DatabaseOperation, InstanceType

cdef class DatabaseClient:
	cdef bint connected
	cdef object reader
	cdef object writer
	cdef Buffer stream
	cdef bytes received

	cdef send(self, DatabaseOperation method, InstanceType instantType, str tableName, list data)
	cdef encodeData(self, DatabaseOperation method, InstanceType instanceType, str tableName, list data)
	cdef decodeData(self, bytes message)