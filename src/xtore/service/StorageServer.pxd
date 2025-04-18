from xtore.BaseType cimport u16
from xtore.service.StorageHandler cimport StorageHandler
from xtore.instance.BasicStorage cimport BasicStorage

cdef class StorageServer :
	cdef dict config
	cdef str host
	cdef u16 port
	cdef StorageHandler storageHandler
	cdef BasicStorage storage