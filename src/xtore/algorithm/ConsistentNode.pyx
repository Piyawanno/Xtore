from xtore.BaseType cimport u16, i32

cdef class ConsistentNode:
	def __init__(self, dict raw):
		self.id = raw.get("id", -1)
		self.host = raw.get("host", "localhost")
		self.port = raw.get("port", 0)
		

	def __str__(self):
		return f"Node(id={self.id}, host={self.host}, port={self.port})"
