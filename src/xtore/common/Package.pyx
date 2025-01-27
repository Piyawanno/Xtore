from xtore.common.Buffer cimport Buffer, getBuffer, initBuffer, releaseBuffer, setBuffer, getString, setString
from xtore.BaseType cimport i16, i64, i32, u64

from libc.stdlib cimport malloc

import json

cdef i32 BUFFER_SIZE

cdef class Package:
	def __repr__(self):
		return f'<Package ID={self.ID} meta={self.header} value={self.data}>'

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