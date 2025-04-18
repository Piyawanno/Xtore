from xtore.BaseType cimport i32
from xtore.common.Buffer cimport initBuffer, releaseBuffer, setBuffer
from xtore.protocol.AsyncProtocol cimport AsyncProtocol
from xtore.protocol.RecordNodeProtocol cimport RecordNodeProtocol

from libc.stdlib cimport malloc

cdef i32 BUFFER_SIZE = 1 << 16

cdef class StorageTransferProtocol (AsyncProtocol):
	def __init__(self, storageHandler, storage):
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		self.storage = storage
		self.storageHandler = storageHandler

	def __dealloc__(self):
		releaseBuffer(&self.stream)

	def __repr__(self):
		return f'<Storage Transfer Protocol>'

	def connection_made(self, object transport):
		self.transport = transport
		print('Connection Made 🚀', end=" ")
		print(*self.transport.get_extra_info('sockname'), sep="@")

	def connection_lost(self, Exception exc):
		print('Connection Lost ⛔', end=" ")
		print(*self.transport.get_extra_info('sockname'), sep="@")
		self.transport = None
		if exc:
			print(f'Exception: <{exc}>')

	def data_received(self, bytes data):
		# Set the received data to the buffer
		cdef i32 dataLength = len(data)
		setBuffer(&self.stream, <char *> data, dataLength)

		# Initial the RecordNodeProtocol
		cdef RecordNodeProtocol received = RecordNodeProtocol()
		cdef bytes response = received.handleRequest(&self.stream, self.storageHandler, self.storage)

		# Send back the response
		self.transport.write(response)