from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i16, i64
from xtore.service.StorageHandler cimport StorageHandler
import os

cdef class Node:
	def __init__(self, dict raw):
		self.handler = StorageHandler({})
		self.host = raw["host"]
		self.port = raw["port"]
		self.getCapacity()

	cdef getCapacity(self):
		cdef str basePath = os.getcwd()
		cdef str path = os.path.join(basePath, f"venvs/db{self.port}.venv/var/xtore/People.BST.bin")
		self.capacity = self.handler.getFileSize(path)