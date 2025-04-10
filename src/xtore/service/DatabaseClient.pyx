from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport releaseBuffer, setBuffer, initBuffer
from xtore.protocol.RecordNodeProtocol cimport RecordNodeProtocol, DatabaseOperation, InstanceType

from libc.stdlib cimport malloc
from cpython cimport PyBytes_FromStringAndSize

cdef i64 BUFFER_SIZE = 1 << 32

cdef class DatabaseClient:
	def __init__(self) :
		self.connected = False
		self.reader = None
		self.writer = None
		self.received = None
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __dealloc__(self) :
		releaseBuffer(&self.stream)

	cdef send(self, DatabaseOperation method, InstanceType instantType, str tableName, list data):
		raise NotImplementedError

	cdef encodeData(self, DatabaseOperation method, InstanceType instanceType, str tableName, list data) :
		cdef RecordNodeProtocol protocol = RecordNodeProtocol()
		cdef i64 position
		protocol.writeHeader(
			operation=method,
			instantType=instanceType, 
			tableName=tableName, 
			version=1
		)
		position = self.stream.position
		protocol.encode(&self.stream, data)
		return PyBytes_FromStringAndSize(self.stream.buffer + position, self.stream.position - position)

	cdef decodeData(self, bytes message) :
		cdef RecordNodeProtocol protocol = RecordNodeProtocol()
		setBuffer(&self.stream, message, len(message))
		self.stream.position -= len(message)
		protocol.getHeader(&self.stream)
		return protocol.decode(&self.stream)