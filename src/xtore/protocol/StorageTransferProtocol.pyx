from xtore.BaseType cimport i32
from xtore.common.Buffer cimport initBuffer, releaseBuffer, setBuffer
from xtore.protocol.AsyncProtocol cimport AsyncProtocol
from xtore.protocol.StorageCommunicateProtocol cimport StorageCommunicateProtocol

from libc.stdlib cimport malloc

cdef i32 BUFFER_SIZE

cdef class StorageTransferProtocol (AsyncProtocol):
	def __init__(self):
		initBuffer(&self.stream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)

	def __dealloc__(self):
		releaseBuffer(&self.stream)

	def __repr__(self):
		return f'<Storage Transfer Protocol>'

	def connection_made(self, object transport):
		self.transport = transport
		print('Connection Made 🎉')

	def connection_lost(self, Exception exc):
		self.transport = None
		print('Connection Lost 🛑')
		if exc:
			print(f'Exception: <{exc}>')

	def data_received(self, bytes data):
		# Set the received data to the buffer
		cdef i32 dataLength = len(data)
		print(f'Cluster Received {dataLength} bytes')
		setBuffer(&self.stream, <char *> data, dataLength)

		# Initial the StorageCommunicateProtocol
		cdef StorageCommunicateProtocol received = StorageCommunicateProtocol()
		cdef bytes response = received.handleRequest(&self.stream)

		# Send back the response
		# self.transport.write(response)
		# print(f'Cluster Sent Response {len(response)} bytes')