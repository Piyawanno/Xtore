from xtore.protocol.ServerProtocol import ServerProtocol

from asyncio import Protocol, BaseTransport

class ReplicaProtocol(ServerProtocol) :
	def __init__(self) :
		self.transport:BaseTransport = None

	def connection_made(self, transport:BaseTransport) :
		self.transport = transport
		peerName:str = self.transport.get_extra_info("peername")
		print(f"Connected From {peerName}")

	def connection_lost(self, exc:Exception) :
		self.transport = None

	def data_received(self, data:bytes) :
		print(data)
		# cdef i32 length = len(message)
		# memcpy(self.stream.buffer, <char *> message, length)
		# cdef People people = People()
		# people.readKey(0, &self.stream)
		# self.stream.position += 4
		# people.readValue(0, &self.stream)
		self.transport.write(data)