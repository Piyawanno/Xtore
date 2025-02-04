from xtore.protocol.ClientProtocol import ClientProtocol

from asyncio import Protocol, BaseTransport, Future

class MasterProtocol(ClientProtocol) :
	def __init__(self, message:bytes) :
		ClientProtocol.__init__(self, message)

	def connection_made(self, transport:BaseTransport) :
		transport.write(self.message)

	def connection_lost(self, exc:Exception) :
		self.on_con_lost.set_result(True)

	def data_received(self, data:bytes) :
		pass