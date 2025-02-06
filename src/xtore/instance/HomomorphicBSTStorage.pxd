from xtore.BaseType cimport i32, i64, byte
from xtore.common.Buffer cimport Buffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.Homomorphic cimport Homomorphic


cdef class HomomorphicBSTStorage (BasicStorage):
	cdef i64 rootPosition
	cdef i64 rootNodePosition
	cdef bint isCreated

	cdef Buffer stream
	cdef Buffer headerStream
	
	cdef Homomorphic homomorphic

	cdef RecordNode comparingNode
