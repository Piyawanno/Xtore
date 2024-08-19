cdef class BufferStream:
	cdef char *buffer
	cdef int position
	cdef int size

	cdef reset(self)
	cdef setBuffer(self, bytes buffer)
	cdef bytes toBytes(self)
	
	cdef setBool(self, bint data)
	cdef bint getBool(self)
	cdef setU8(self, unsigned char data)
	cdef unsigned char getU8(self)
	cdef setI16(self, short data)
	cdef short getI16(self)
	cdef setI32(self, int data)
	cdef int getI32(self)
	cdef setI64(self, long data)
	cdef long getI64(self)
	cdef setF64(self, double data)
	cdef double getF64(self)
