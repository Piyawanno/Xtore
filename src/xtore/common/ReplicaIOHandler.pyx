from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer
from xtore.service.Client cimport Client
from xtore.BaseType cimport u8

from cpython cimport PyBytes_FromStringAndSize
import os

cdef class ReplicaIOHandler(StreamIOHandler) :
	def __init__(self, str fileName, str path, list replicaList) :
		StreamIOHandler.__init__(self, path)
		self.fileName = fileName
		self.replicaList = replicaList

	cdef write(self, Buffer *stream) :
		StreamIOHandler.write(self, stream)
		cdef bytes encoded = self.fileName.encode()
		cdef bytes data = PyBytes_FromStringAndSize(stream.buffer, stream.position)
		cdef bytes message = len(encoded).to_bytes(2, "little") + encoded + data
		cdef dict replica
		cdef Client service
		for replica in self.replicaList :
			service = Client(replica)
			service.sendSync(message, self.handle)
	
	def handle(self, bytes message) :
		print(message)