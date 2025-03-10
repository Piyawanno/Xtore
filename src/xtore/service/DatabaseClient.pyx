from xtore.BaseType cimport i32
from xtore.protocol.RecordNodeProtocol cimport DatabaseOperation, InstanceType

cdef i32 BUFFER_SIZE = 1 << 16

cdef class DatabaseClient:
	def __init__(self, list[dict] nodeList, dict config) :
		self.connected = False
		self.reader = None
		self.writer = None
		self.received = None

	def send(self, method: DatabaseOperation, instantType: InstanceType, data: list):
		raise NotImplementedError

	cdef encodeData(self, DatabaseOperation method, InstanceType instanceType, list data):
		raise NotImplementedError