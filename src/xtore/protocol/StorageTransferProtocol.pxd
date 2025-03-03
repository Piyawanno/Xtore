from xtore.BaseType cimport i32
from xtore.common.Buffer cimport Buffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.protocol.AsyncProtocol cimport AsyncProtocol
from xtore.service.StorageService cimport StorageService

cdef class StorageTransferProtocol (AsyncProtocol):
	cdef Buffer stream
	cdef StorageService storageService
	cdef list[BasicStorage] storageList
