from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i64
from posix cimport fcntl, unistd

import os

cdef class ReplicaIOHandler(StreamIOHandler) :
	def __init__(self, str path, list replicaList) :
		StreamIOHandler.__init__(self, path)
		self.path = path
		self.replicaList = replicaList
		self.tail = 0
		cdef int fd
	
	cdef open(self) :
		StreamIOHandler.open(self)
		
	cdef close(self) :
		StreamIOHandler.close(self)
	
	cdef i64 reserve(self, int size) :
		if unistd.ftruncate(self.fd, self.tail+size) < 0 :
			raise IOError
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		return self.tail

	cdef seek(self, i64 position) :
		StreamIOHandler.seek(self, position)
	
	cdef read(self, Buffer *stream, int size) :
		StreamIOHandler.read(self, stream, size)

	cdef write(self, Buffer *stream) :
		StreamIOHandler.write(self, stream)
		# cdef dict config
		# cdef ClientService service
		# for config in self.config.get("replica", []) :
		# 	service = ClientService(config)
		# 	service.send(MasterProtocol, message)
	
	cdef writeOffset(self, Buffer *stream, i32 offset, i32 size) :
		StreamIOHandler.writeOffset(self, stream, offset, size)

	cdef i64 append(self, Buffer *stream) :
		return self.fill(stream)
	
	cdef i64 fill(self, Buffer *stream) :
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		unistd.write(self.fd, stream.buffer, stream.position)
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		return self.tail

	cdef i64 getTail(self) :
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		return self.tail
