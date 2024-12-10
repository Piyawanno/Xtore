#cython: language_level=3

from libc cimport string
from cpython cimport PyMem_Malloc, PyMem_Free, PyBytes_FromStringAndSize

cdef class BufferStream:
	# cdef char *buffer
	# cdef int position
	# cdef int size

	def __init__(self, int size):
		self.size = size
		self.position = 0
		self.buffer = <char*> PyMem_Malloc(size)
	
	def __dealloc__(self):
		PyMem_Free(self.buffer)
	
	cdef reset(self):
		self.position = 0
	
	cdef setBuffer(self, bytes buffer):
		cdef int n = len(buffer)
		if n > self.size: n = self.size
		cdef char *pointer = buffer
		string.memcpy(self.buffer, pointer, n)
		self.position = 0
	
	cdef bytes toBytes(self):
		return PyBytes_FromStringAndSize(self.buffer, self.position)

	cdef setBool(self, bint data):
		cdef bint[1] array
		array[0] = data
		string.memcpy(self.buffer+self.position, array, 1)
		self.position += 1
	
	cdef bint getBool(self):
		cdef bint[1] array
		string.memcpy(array, self.buffer+self.position, 1)
		self.position += 1
		return array[0]

	cdef setU8(self, unsigned char data):
		self.buffer[self.position] = data
		self.position += 1

	cdef unsigned char getU8(self):
		cdef unsigned char data
		data = self.buffer[self.position]
		self.position += 1
		return data

	cdef setI16(self, short data):
		cdef short[1] array
		array[0] = data
		string.memcpy(self.buffer+self.position, array, 2)
		self.position += 2
	
	cdef short getI16(self):
		cdef short[1] array
		string.memcpy(array, self.buffer+self.position, 2)
		self.position += 2
		return array[0]

	cdef setI32(self, int data):
		cdef int[1] array
		array[0] = data
		string.memcpy(self.buffer+self.position, array, 4)
		self.position += 4
	
	cdef int getI32(self):
		cdef int[1] array
		string.memcpy(array, self.buffer+self.position, 4)
		self.position += 4
		return array[0]
	
	cdef setI64(self, long data):
		cdef long[1] array
		array[0] = data
		string.memcpy(self.buffer+self.position, array, 8)
		self.position += 8
	
	cdef long getI64(self):
		cdef long[1] array
		string.memcpy(array, self.buffer+self.position, 8)
		self.position += 8
		return array[0]
	
	cdef setF64(self, double data):
		cdef double[1] array
		array[0] = data
		string.memcpy(self.buffer+self.position, array, 8)
		self.position += 8
	
	cdef double getF64(self):
		cdef double[1] array
		string.memcpy(array, self.buffer+self.position, 8)
		self.position += 8
		return array[0]
