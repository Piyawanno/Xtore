from xtore.common.Buffer cimport Buffer, getBuffer, initBuffer, releaseBuffer, setBuffer, getString, setString
from xtore.BaseType cimport i8, u8, i16, i32
from xtore.instance.RecordNode cimport RecordNode

from libc.stdlib cimport malloc

import uuid

cdef i32 BUFFER_SIZE

cdef class ClusterProtocol:
	def __init__(self):
		self.classMapper = {}
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __repr__(self):
		return f'<Protocol meta={self.operation} table={self.tableName} count={self.recordCount}>'

	def __dealloc__(self):
		releaseBuffer(&self.stream)

	cdef registerClass(self, str tableName, object recordClass):
		self.classMapper[tableName] = recordClass

	cdef packForSet(self, Buffer *stream, str tableName, list[RecordNode] recordList):
		cdef u8 operation = self.operation
		cdef u8 type = self.type
		cdef i32 n = len(recordList)
		cdef RecordNode record
		setBuffer(stream, <char *> &operation, 1)
		setBuffer(stream, <char *> &type, 1)
		setString(stream, self.tableName)
		setBuffer(stream, <char *> &n, 4)
		for record in recordList:
			record.write(stream)
	
	cdef list[RecordNode] unpackForSet(self, Buffer *stream):
		cdef list[RecordNode] result = []
		cdef object recordClass = self.classMapper.get(self.tableName, None)
		if recordClass is None: return result
		cdef i16 version = 0
		cdef i32 n = (<i32 *> getBuffer(stream, 4))[0]
		cdef RecordNode record
		cdef Buffer idStream
		initBuffer(&idStream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		for i in range(n):
			setBuffer(&idStream, uuid.uuid4().bytes, 16)
			record = recordClass()
			record.readKey(version, &idStream)
			record.readValue(version, stream)
			result.append(record)
		releaseBuffer(&idStream)
		return result

	cdef getHeader(self, Buffer *stream):
		self.operation = (<DatabaseOperation *>getBuffer(stream, 1))[0]
		self.type = (<InstanceType *> getBuffer(stream, 1))[0]
		self.tableName = getString(stream)
		self.version = (<i16 *> getBuffer(stream, 2))[0]
		self.recordCount = (<i32 *> getBuffer(stream, 4))[0]

	cdef connection_made(self, object transport):
		self.transport = transport
		print('Connection Made')

	cdef data_received(self, bytes data):
		cdef i32 length = len(data)
		setBuffer(&self.stream, <char *> data, length)
		cdef ClusterProtocol recieved = ClusterProtocol()
		self.stream.position -= length
		recieved.getHeader(&self.stream)
		if recieved.operation == GET:
			pass
		elif recieved.operation == SET:
			recieved.unpackForSet(&self.stream)
			print(f'Get data {recieved}')
		else:
			print(f'Operation {recieved.operation} not found !')

	cdef connection_lost(self, Exception exc):
		self.transport = None
		print('Connection Lost')