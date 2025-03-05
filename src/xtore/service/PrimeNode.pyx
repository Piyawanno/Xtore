from xtore.BaseType cimport u16, i32

cdef class PrimeNode:
	def __init__(self, dict raw):
		self.children = []
		self.id = raw["ringId"]
		self.host = raw["host"]
		self.port = raw["port"]
		self.layer = raw["layer"]
		self.isMaster = raw["isMaster"]

	def __str__(self):
		return f"Node(id={self.id}, host={self.host}, port={self.port}, layer={self.layer}, children={self.children}, isMaster={self.isMaster})"
