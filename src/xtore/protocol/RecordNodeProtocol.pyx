from xtore.common.Buffer cimport Buffer, getBuffer, initBuffer, releaseBuffer, setBuffer, getString, setString
from xtore.BaseType cimport u8, i16, i32
from xtore.instance.RecordNode cimport RecordNode
from xtore.service.StorageHandler cimport StorageHandler
from xtore.test.People cimport People

from libc.stdlib cimport malloc

from cpython cimport PyBytes_FromStringAndSize

cdef i32 BUFFER_SIZE = 1 << 16

cdef class RecordNodeProtocol:
	def __init__(self):
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		self.classMapper = {}
		self.registerClass("People", People)

	def __repr__(self):
		return f'<Protocol meta={self.operation} table={self.tableName} count={self.recordCount}>'

	def __dealloc__(self):
		releaseBuffer(&self.stream)

	cdef encode(self, Buffer *stream, list[RecordNode] recordList):
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

	cdef registerClass(self, str tableName, object recordClass):
		self.classMapper[tableName] = recordClass

	cdef writeHeader(self, DatabaseOperation operation, InstanceType instantType, str tableName, i16 version):
		self.operation = operation
		self.type = instantType
		self.tableName = tableName
		self.version = version

	cdef getHeader(self, Buffer *stream):
		self.operation = <DatabaseOperation> ((<u8 *> getBuffer(stream, 1))[0])
		self.type = <InstanceType> ((<u8 *> getBuffer(stream, 1))[0])
		self.tableName = getString(stream)
		self.version = (<i16 *> getBuffer(stream, 2))[0]
		self.recordCount = (<i32 *> getBuffer(stream, 4))[0]

	cdef bytes handleRequest(self, Buffer *stream, StorageHandler handler, BasicStorage storage):
		cdef i32 status = 0
		stream.position = 0
		self.getHeader(stream)
		if self.operation == DatabaseOperation.GETALL:
			print(f'>> Called Method - GETALL')
			if self.type == InstanceType.BST:
				print(f'>> Reading BSTStorage {self.tableName}')
				queryResponse = handler.readAllBSTStorage(storage)
			print(f'>> Sending {len(queryResponse)} records')
			self.encode(&self.stream, queryResponse)
			return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)
		elif self.operation == DatabaseOperation.SET:
			recordList = self.decode(stream)
			print(f'>> Received {len(recordList)} records')
			if self.type == InstanceType.BST:
				status = handler.writeToStorage(recordList, storage)
				if status == 1:
					print("❗️Write failed: storage full.")
					self.stream.position = 0
					self.encode(&self.stream, [])
					return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)
			self.encode(&self.stream, recordList)
			return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)
		elif self.operation == DatabaseOperation.GET:
			recordList = self.decode(stream)
			print(f'>> Received {len(recordList)} keys')
			queryResponse = handler.readData(storage, recordList)
			print(f'>> Sending {len(recordList)} records')
			self.encode(&self.stream, queryResponse)
			return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)
		else:
			print(f'Operation {self.operation} not found !')
		return PyBytes_FromStringAndSize(self.stream.buffer, self.stream.position)
