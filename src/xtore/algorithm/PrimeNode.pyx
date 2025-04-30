from xtore.BaseType cimport i32
from xtore.algorithm.Node cimport Node
from xtore.service.StorageHandler cimport StorageHandler

import os

cdef class PrimeNode(Node):
	def __init__(self, dict raw):
		Node.__init__(self, raw)
		self.isMaster = raw["isMaster"]

	def __str__(self):
		return f"Node(host={self.host}, port={self.port}, isMaster={self.isMaster}, capacity={self.capacity})"