from xtore.BaseType cimport u16, i32

cdef class PrimeNode:
	def __init__(self, dict raw):
		self.host = raw["host"]
		self.port = raw["port"]
		self.isMaster = raw["isMaster"]

	def __str__(self):
		return f"Node(host={self.host}, port={self.port}, isMaster={self.isMaster})"
