from asyncio import Protocol, BaseTransport, Future

class ClientProtocol(Protocol) :
	def __init__(self, message:bytes) :
		self.message:bytes = message

	def connection_made(self, transport:BaseTransport) :
		raise f"{self.__class__.__name__} connection_made not implemented."

	def connection_lost(self, exc:Exception) :
		raise f"{self.__class__.__name__} connection_lost not implemented."

	def data_received(self, data:bytes) :
		raise f"{self.__class__.__name__} data_received not implemented."