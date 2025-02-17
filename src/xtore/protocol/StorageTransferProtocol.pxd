from xtore.BaseType cimport i32
from xtore.common.Buffer cimport Buffer
from xtore.protocol.AsyncProtocol cimport AsyncProtocol

cdef class StorageTransferProtocol (AsyncProtocol):
	cdef Buffer stream
