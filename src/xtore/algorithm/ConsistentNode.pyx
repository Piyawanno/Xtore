from xtore.BaseType cimport u16, i32

cdef class ConsistentNode:
	def __init__(self, dict raw):
		self.id = raw["id"]
		self.host = raw["host"]
		self.port = raw["port"]
		

	def __str__(self):
		return f"Node(id={self.id}, host={self.host}, port={self.port})"
