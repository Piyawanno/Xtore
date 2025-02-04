from xtore.common.Buffer cimport Buffer, getBuffer, initBuffer, releaseBuffer, setBuffer, getString, setString
from xtore.BaseType cimport u8, i16, i32
from xtore.instance.RecordNode cimport RecordNode
from xtore.test.People cimport People
from xtore.protocol.AsyncProtocol cimport AsyncProtocol


from libc.stdlib cimport malloc

import uuid

cdef i32 BUFFER_SIZE

cdef class ClusterProtocol (AsyncProtocol):
	def __init__(self):
		self.classMapper = {}
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __repr__(self):
		return f'<Protocol meta={self.operation} table={self.tableName} count={self.recordCount}>'

	def __dealloc__(self):
		releaseBuffer(&self.stream)

	cdef registerClass(self, str tableName, object recordClass):
		self.classMapper[tableName] = recordClass

	cdef code(self, Buffer *stream, list[RecordNode] recordList):
		cdef u8 operation = self.operation
		cdef u8 type = self.type
		cdef str table = self.tableName
		cdef i32 n = len(recordList)
		cdef RecordNode record
		setBuffer(stream, <char *> &operation, 1)
		setBuffer(stream, <char *> &type, 1)
		setString(stream, table)
		setBuffer(stream, <char *> &self.version, 2)
		setBuffer(stream, <char *> &n, 4)
		for record in recordList:
			record.write(stream)
	
	cdef list[RecordNode] decode(self, Buffer *stream):
		cdef list[RecordNode] result = []
		cdef object recordClass = self.classMapper.get(self.tableName, None)
		if recordClass is None: 
			print(f'Record Class for {self.tableName} not found !')
			return result
		cdef i16 version = self.version
		cdef i32 n = self.recordCount
		cdef RecordNode record
		for i in range(n):
			record = recordClass()
			record.readKey(version, stream)
			stream.position += 4
			record.readValue(version, stream)
			result.append(record)
		return result

	cdef getHeader(self, Buffer *stream):
		self.operation = <DatabaseOperation> ((<u8 *> getBuffer(stream, 1))[0])
		self.type = <InstanceType> ((<u8 *> getBuffer(stream, 1))[0])
		self.tableName = getString(stream)
		self.version = (<i16 *> getBuffer(stream, 2))[0]
		self.recordCount = (<i32 *> getBuffer(stream, 4))[0]

	def connection_made(self, object transport):
		self.transport = transport
		print('Connection Made')

	def connection_lost(self, Exception exc):
		self.transport = None
		print('Connection Lost')

	def data_received(self, bytes data):
		cdef i32 length = len(data)
		print(f'Cluster Received {length} bytes')
		setBuffer(&self.stream, <char *> data, length)
		cdef ClusterProtocol received = ClusterProtocol()
		received.registerClass("People", People)
		self.stream.position -= length
		received.getHeader(&self.stream)
		print(received.operation)
		if received.operation == DatabaseOperation.GET:
			pass
		elif received.operation == DatabaseOperation.SET:
			received.decode(&self.stream)
			print(f'Get data {received}')
		else:
			print(f'Operation {received.operation} not found !')
		self.transport.write(data)