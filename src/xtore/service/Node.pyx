from xtore.BaseType cimport u16, i32

cdef class Node:
	def __init__(self):
		self.children = []
		self.replicas = []
		#self.id = -1
		#self.port = -1
		#self.isMaster = -1
		#self.layer = -1

	def __str__(self):
		return f"Node(id={self.id}, host={self.host}, port={self.port}, isMaster={self.isMaster}, layer={self.layer}, children={self.children}, replicas={self.replicas})"
