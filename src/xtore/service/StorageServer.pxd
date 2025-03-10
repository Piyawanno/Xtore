from xtore.BaseType cimport u16
from xtore.service.StorageHandler cimport StorageHandler

cdef class StorageServer :
	cdef dict config
	cdef str host
	cdef u16 port
	cdef StorageHandler storageHandler
	cdef list storageList