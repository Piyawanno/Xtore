import asyncio

cdef class AsyncProtocol :
	def connection_made(self, object transport):
		raise NotImplementedError

	def connection_lost(self, Exception exc):
		raise NotImplementedError

	def data_received(self, bytes data):
		raise NotImplementedError
