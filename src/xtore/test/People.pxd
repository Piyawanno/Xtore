from xtore.HashNode cimport HashNode
from xtore.Buffer cimport Buffer
from xtore.BaseType cimport u64

cdef class People (HashNode):
    cdef u64 ID
    cdef str name
    cdef str surname