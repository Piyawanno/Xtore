from xtore.protocol.AsyncProtocol cimport AsyncProtocol

cdef class EchoProtocol (AsyncProtocol):
	def connection_made(self, object transport):
		self.transport = transport

	def connection_lost(self, Exception exc):
		self.transport = None

	def data_received(self, bytes data):
		print(f"Received {len(data)} bytes")
		self.transport.write(data)
