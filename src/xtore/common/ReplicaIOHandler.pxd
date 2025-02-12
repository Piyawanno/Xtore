from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.Buffer cimport Buffer
from xtore.BaseType cimport i32, i64

cdef class ReplicaIOHandler(StreamIOHandler) :
	cdef str fileName
	cdef list replicaList