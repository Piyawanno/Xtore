from re import T

from xtore.instance.BasicStorage cimport BasicStorage
from xtore.test.People cimport People

cdef class StorageService:
	cdef dict config

	cdef assignID(self, People record)
	cdef writeHashStorage(self, list[People] dataList)
	cdef writeData(self, BasicStorage storage, list[T] data)
	cdef checkPath(self)
	cdef str getResourcePath(self)