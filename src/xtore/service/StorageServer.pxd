from xtore.BaseType cimport u16
from xtore.service.StorageService cimport StorageService

cdef class StorageServer :
	cdef dict config
	cdef str host
	cdef u16 port
	cdef StorageService storageService
	cdef list storageList