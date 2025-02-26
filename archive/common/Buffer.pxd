from xtore.BaseType cimport u8, u16, u64
from libc.string cimport memcpy
from libc.stdlib cimport malloc, free
from cpython cimport PyBytes_FromStringAndSize

cdef struct Buffer :
	u64 position
	u64 capacity
	char *buffer

ctypedef void (* CapacityChecker) (Buffer *self, u64 length)

cdef inline void initBuffer(Buffer *self, char *buffer, u64 capacity):
	self.buffer = buffer
	self.capacity = capacity
	self.position = 0

cdef inline void resizeBuffer(Buffer *self, char *buffer, u64 capacity):
	if capacity > self.capacity:
		memcpy(buffer, self.buffer, self.position)
		releaseBuffer(self)
		self.buffer = buffer
		self.capacity = capacity

cdef inline void checkBufferSize(Buffer *self, u64 chunkSize):
	cdef int capacity
	cdef char *buffer
	if self.position >= self.capacity:
		capacity = self.capacity + chunkSize
		buffer = <char *> malloc(capacity)
		resizeBuffer(self, buffer, capacity)

cdef inline void setBuffer(Buffer *self, char *buffer, u64 length) :
	memcpy(self.buffer+self.position, buffer, length)
	self.position += length

cdef inline void setBytes(Buffer *self, bytes buffer):
	cdef u16 length = len(buffer)
	setBuffer(self, <char* > &length, 2)
	memcpy(self.buffer+self.position, <char *> buffer, length)
	self.position += length


cdef inline void setString(Buffer *self, str text):
	cdef bytes buffer = text.encode()
	cdef u16 length = len(buffer)
	setBuffer(self, <char* > &length, 2)
	memcpy(self.buffer+self.position, <char *> buffer, length)
	self.position += length

cdef inline void setBoolean(Buffer *self, bint data) :
	cdef u8 converted = 1 if data else 0
	setBuffer(self, <char *> &converted, 1)

cdef inline char *getBuffer(Buffer *self, u64 length) :
	cdef char *buffer = self.buffer + self.position
	self.position += length
	return buffer

cdef inline str getString(Buffer *self):
	cdef u16 length = (<u16*> getBuffer(self, 2))[0]
	cdef char *pointer = getBuffer(self, length)
	cdef bytes buffer = PyBytes_FromStringAndSize(pointer, length)
	return buffer.decode()

cdef inline bytes getBytes(Buffer *self):
	cdef u16 length = (<u16*> getBuffer(self, 2))[0]
	cdef char *pointer = getBuffer(self, length)
	cdef bytes buffer = PyBytes_FromStringAndSize(pointer, length)
	return buffer

cdef inline bint getBoolean(Buffer *self) :
	cdef u8 data = (<u8*> getBuffer(self, 1))[0]
	return data > 0

cdef inline releaseBuffer(Buffer *self):
	if self.capacity > 0 and self.buffer != NULL:
		free(self.buffer)
		self.capacity = 0
		self.buffer = NULL