from xtore.BaseType cimport i32, i64, u16
from xtore.service.StorageHandler cimport StorageHandler

cdef class PrimeNode:
	cdef str host
	cdef u16 port
	cdef i32 isMaster
	cdef i64 capacity
	cdef StorageHandler handler

	cdef getCapacity(self)