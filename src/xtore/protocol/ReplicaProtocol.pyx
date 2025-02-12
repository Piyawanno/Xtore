from xtore.protocol.AsyncProtocol cimport AsyncProtocol
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer, initBuffer, releaseBuffer, getString, setBuffer
from xtore.BaseType cimport u16, i32, i64

from libc.stdlib cimport malloc
from libc.string cimport memcpy
import os, sys, traceback

cdef bint IS_VENV = sys.prefix != sys.base_prefix
cdef i32 BUFFER_SIZE = 1 << 16

cdef class ReplicaProtocol(AsyncProtocol) :
	# def __init__(self, StreamIOHandler io) :
	def __init__(self) :
		self.transport = None
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __dealloc__(self):
		releaseBuffer(&self.stream)

	def connection_made(self, object transport) :
		self.transport = transport
		peerName:tuple = self.transport.get_extra_info("peername")
		print(f"Connected From {peerName}")

	def connection_lost(self, Exception exc) :
		self.transport = None

	def data_received(self, bytes data) :
		cdef i32 length = len(data)
		cdef u16 nameLength = <u16> int.from_bytes(data[:2], "little")
		cdef str fileName = data[2:nameLength + 2].decode()
		cdef bytes message = data[nameLength + 2:]
		cdef i32 messageLength = length - (nameLength + 2)
		setBuffer(&self.stream, <char *> message, messageLength)
		cdef str resourcePath = self.getResourcePath()
		cdef str path = os.path.join(resourcePath, fileName)
		cdef StreamIOHandler io = StreamIOHandler(path)
		io.open()
		try:
			io.write(&self.stream)
		except:
			print(traceback.format_exc())
		io.close()
		self.transport.write(b"success")
	
	cdef str getResourcePath(self) :
		cdef str resourcePath
		if IS_VENV: resourcePath = os.path.join(sys.prefix, "var", "xtore")
		else: resourcePath = os.path.join('/', "var", "xtore")
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)
		return resourcePath