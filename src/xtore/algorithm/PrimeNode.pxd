from xtore.BaseType cimport i32, i64, u16
from xtore.service.StorageHandler cimport StorageHandler
from xtore.algorithm.Node cimport Node

cdef class PrimeNode(Node):
	cdef i32 isMaster