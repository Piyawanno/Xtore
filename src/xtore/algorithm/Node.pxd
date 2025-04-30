from xtore.BaseType cimport i64, u16
from xtore.service.StorageHandler cimport StorageHandler

cdef class Node:
	cdef str host
	cdef u16 port
	cdef StorageHandler handler
	cdef i64 capacity

	cdef getCapacity(self)