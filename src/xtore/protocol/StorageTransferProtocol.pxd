from xtore.BaseType cimport i32
from xtore.common.Buffer cimport Buffer
from xtore.protocol.AsyncProtocol cimport AsyncProtocol

cdef i32 BUFFER_SIZE = 1 << 16

cdef class StorageTransferProtocol (AsyncProtocol):
	cdef Buffer stream
