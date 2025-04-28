from xtore.BaseType cimport i32
from xtore.service.StorageHandler cimport StorageHandler
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.test.PeopleBSTStorage cimport PeopleBSTStorage

import os

cdef class PrimeNode:
	def __init__(self, dict raw):
		self.handler = StorageHandler({})
		self.host = raw["host"]
		self.port = raw["port"]
		self.isMaster = raw["isMaster"]
		self.getCapacity()

	def __str__(self):
		return f"Node(host={self.host}, port={self.port}, isMaster={self.isMaster}, capacity={self.capacity})"

	cdef getCapacity(self):
		cdef str basePath = os.getcwd()
		cdef str path = os.path.join(basePath, f"venvs/db{self.port}.venv/var/xtore/People.BST.bin")
		self.capacity = self.handler.getFileSize(path)

