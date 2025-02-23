from xtore.BaseType cimport u16, i32

cdef class Node:
	def __init__(self, dict raw, i32 layer):
		self.children = []
		self.replicas = raw["storageUnit"]["replica"]
		self.id = raw["ringId"]
		self.host = raw["storageUnit"]["master"]["host"]
		self.port = raw["storageUnit"]["master"]["port"]
		self.layer = layer

	def __str__(self):
		return f"Node(id={self.id}, host={self.host}, port={self.port}, layer={self.layer}, children={self.children}, replicas={self.replicas})"
