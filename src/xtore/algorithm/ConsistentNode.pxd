from xtore.BaseType cimport u16, i32
from xtore.algorithm.Node cimport Node

cdef class ConsistentNode(Node):
	cdef public i32 id