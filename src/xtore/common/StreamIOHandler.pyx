from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i64
from posix cimport fcntl, unistd

import os

cdef class StreamIOHandler:
	def __init__(self, str path):
		self.path = path
	
	cdef open(self):
		if not os.path.isfile(self.path):
			with open(self.path, 'wb') as fd:
				fd.write(b'')
		cdef bytes path = self.path.encode()
		self.fd = fcntl.open(path, fcntl.O_RDWR)
		if self.fd < 0:
			raise IOError
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		
	cdef close(self):
		unistd.close(self.fd)
	
	cdef i64 reserve(self, int size):
		if unistd.ftruncate(self.fd, self.tail+size) < 0:
			raise IOError
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		return self.tail

	cdef seek(self, i64 position):
		unistd.lseek(self.fd, position, fcntl.SEEK_SET)
	
	cdef read(self, Buffer *stream, int size):
		if size > stream.capacity:
			raise ValueError("Required size exceeds StreamBuffer size.")
		stream.position = 0
		unistd.read(self.fd, stream.buffer, size)

	cdef write(self, Buffer *stream):
		unistd.write(self.fd, stream.buffer, stream.position)
	
	cdef writeOffset(self, Buffer *stream, i32 offset, i32 size):
		unistd.write(self.fd, stream.buffer+offset, size)

	cdef i64 append(self, Buffer *stream):
		return self.fill(stream)
	
	cdef i64 fill(self, Buffer *stream):
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		unistd.write(self.fd, stream.buffer, stream.position)
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		return self.tail

	cdef i64 getTail(self):
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		return self.tail
