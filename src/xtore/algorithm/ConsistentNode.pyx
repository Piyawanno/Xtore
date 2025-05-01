from xtore.BaseType cimport u16, i32
from xtore.algorithm.Node cimport Node

cdef class ConsistentNode(Node):
	def __init__(self, dict raw):
		Node.__init__(self, raw)
		self.id = raw.get("id", -1)	

	def __str__(self):
		return f"Node(id={self.id}, host={self.host}, port={self.port})"
