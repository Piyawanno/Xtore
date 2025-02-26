from xtore.BaseType cimport u8, u16, u64

from libc.string cimport memcpy
from libc.stdlib cimport malloc, free
from cpython cimport PyObject, PyBytes_FromStringAndSize

cdef extern from "xtorecpp/Buffer.hpp" namespace "Xtore":
	cdef enum:
		BUFFER_BLOCK
		BUFFER_MODULUS
		BUFFER_SHIFT

	cdef struct Buffer:
		u64 position
		u64 capacity
		bint hasOwnBuffer

		char *buffer

		bint hasChunked
		PyObject *chunked
		void *checkCapacity

	ctypedef void (* CapacityChecker) (Buffer *self, u64 length)
	cdef void initBuffer(Buffer *self, char *buffer, u64 capacity)
	cdef void releaseBuffer(Buffer *self)
	cdef void checkCapacity(Buffer *self, u64 length)
	cdef void resizeBuffer(Buffer *self, char *buffer, u64 capacity)
	cdef void checkBufferSize(Buffer *self, u64 chunkSize)
	cdef void setBuffer(Buffer *self, char *buffer, u64 length)
	cdef char *getBuffer(Buffer *self, u64 length)

cdef inline void setBytes(Buffer *self, bytes buffer):
	cdef u16 length = len(buffer)
	setBuffer(self, <char* > &length, 2)
	memcpy(self.buffer+self.position, <char *> buffer, length)
	self.position += length

cdef inline bytes getBytes(Buffer *self):
	cdef u16 length = (<u16*> getBuffer(self, 2))[0]
	cdef char *pointer = getBuffer(self, length)
	cdef bytes buffer = PyBytes_FromStringAndSize(pointer, length)
	return buffer

cdef inline void setString(Buffer *self, str text):
	cdef bytes buffer = text.encode()
	cdef u16 length = len(buffer)
	setBuffer(self, <char* > &length, 2)
	memcpy(self.buffer+self.position, <char *> buffer, length)
	self.position += length

cdef inline str getString(Buffer *self):
	cdef u16 length = (<u16*> getBuffer(self, 2))[0]
	cdef char *pointer = getBuffer(self, length)
	cdef bytes buffer = PyBytes_FromStringAndSize(pointer, length)
	return buffer.decode()

cdef inline void setBoolean(Buffer *self, bint data) :
	cdef u8 converted = 1 if data else 0
	setBuffer(self, <char *> &converted, 1)

cdef inline bint getBoolean(Buffer *self) :
	cdef u8 data = (<u8*> getBuffer(self, 1))[0]
	return data > 0
