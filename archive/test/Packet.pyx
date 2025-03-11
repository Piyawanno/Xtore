from xtore.common.Buffer cimport Buffer, getBuffer, initBuffer, releaseBuffer, setBuffer, getString, setString
from xtore.BaseType cimport u8, i16, i64, i32, u64

from libc.stdlib cimport malloc

import json

cdef i32 BUFFER_SIZE

cdef class Packet:
	def __init__(self):
		self.classMapper = {}

	def __repr__(self):
		return f'<Packet ID={self.ID} meta={self.header} value={self.data}>'

	cdef registerClass(self, str tableName, object recordClass):
		self.classMapper[tableName] = recordClass

	cdef code(self, Buffer *stream, str tableName, list[RecordNode] recordList):
		# cdef DatabaseOperation operation
		# cdef InstanceType type
		# cdef str tableName

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
	
	cdef list[RecordNode] decode(self, Buffer *stream):
		cdef list[RecordNode] result = []
		cdef str tableName = getString(stream)
		cdef object recordClass = self.classMapper.get(tableName, None)
		if recordClass is None: return result
		cdef i16 version = 0
		cdef i32 n = (<i32 *> getBuffer(stream, 4))[0]
		cdef RecordNode record
		for i in range(n):
			record = recordClass()
			record.readKey(version, stream)
			record.readValue(version, stream)
			result.append(record)
		return result

	cdef readKey(self, Buffer *stream):
		self.ID = (<i64*> getBuffer(stream, 8))[0]

	cdef readValue(self, Buffer *stream):
		self.header = getString(stream)
		self.data = getString(stream)

	cdef write(self, Buffer *stream):
		setBuffer(stream, <char *> &self.ID, 8)
		cdef i32 start = stream.position
		stream.position += 4
		setString(stream, self.header)
		setString(stream, self.data)
		cdef i32 end = stream.position
		cdef i32 valueSize = end - start
		stream.position = start
		setBuffer(stream, <char *> &valueSize, 4)
		stream.position = end

	cdef getHeader(self):
		return json.loads(self.header)

	cdef u64 hash(self, Buffer *stream):
		# not implemented yet
		return <u64>stream
	
	cdef i32 compareHash(self, u64 hashStream):
		cdef Buffer stream
		initBuffer(&stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		self.write(&stream)
		if self.hash(&stream) == hashStream: 
			releaseBuffer(&stream)
			return 1
		else: 
			releaseBuffer(&stream)
			return 0