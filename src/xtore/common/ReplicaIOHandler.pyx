from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer
from xtore.service.Client cimport Client
from xtore.BaseType cimport u8

from cpython cimport PyBytes_FromStringAndSize
from posix cimport fcntl, unistd
import os, asyncio

cdef class ReplicaIOHandler(StreamIOHandler) :
	def __init__(self, str fileName, str path, list replicaList) :
		StreamIOHandler.__init__(self, path)
		self.fileName = fileName
		self.replicaList = replicaList

	cdef write(self, Buffer *stream) :
		StreamIOHandler.write(self, stream)
		self.replicate(stream, 0, stream.position)
	
	cdef writeOffset(self, Buffer *stream, i32 offset, i32 size) :
		StreamIOHandler.writeOffset(self, stream, offset, size)
		self.replicate(stream, offset, size)
	
	cdef i64 fill(self, Buffer *stream) :
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		unistd.write(self.fd, stream.buffer, stream.position)
		self.tail = unistd.lseek(self.fd, 0, fcntl.SEEK_END)
		self.replicate(stream, 0, stream.position)
		return self.tail
	
	cdef replicate(self, Buffer *stream, i32 offset, i32 size) :
		cdef bytes encoded = self.fileName.encode()
		cdef bytes data = PyBytes_FromStringAndSize(stream.buffer + offset, size)
		cdef bytes message = len(encoded).to_bytes(2, "little") + encoded + data
		asyncio.create_task(self.handle(message))
		# cdef dict replica
		# cdef Client service
		# for replica in self.replicaList :
		# 	service = Client(replica) # add attribute
		# 	service.sendSync(message, self.handle)
	
	# def handle(self, bytes message) :
	# 	print(message)
	
	async def handle(self, bytes message) :
		self.clientList = []
		coroutines = [i.send(message) for i in self.clientList]
		result = await asyncio.gather(*coroutines)