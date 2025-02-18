from xtore.BaseType cimport u16, i32

cdef class Node:
	def __init__(self, dict raw):
		self.children = []
		self.replicas = []
		self.id = raw["id"]
		self.host = raw["host"]
		self.port = raw["port"]
		self.isMaster = -1
		self.layer = -1

	def __str__(self):
		return f"Node(id={self.id}, host={self.host}, port={self.port}, isMaster={self.isMaster}, layer={self.layer}, children={self.children}, replicas={self.replicas})"
