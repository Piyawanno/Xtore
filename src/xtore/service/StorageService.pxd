from xtore.BaseType cimport i32
from xtore.common.Buffer cimport Buffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.RecordNode cimport RecordNode
from xtore.test.People cimport People

cdef class StorageService:
	cdef dict config
	cdef Buffer buffer

	cdef assignID(self, People record)
	cdef writeData(self, BasicStorage storage, list[RecordNode] data)
	cdef writeHashStorage(self, list[People] dataList)
	cdef writeRTStorage(self, list[People] dataList)
	cdef writeBSTStorage(self, list[People] dataList)
	cdef readHashStorage(self, str storageName)
	cdef readRTStorage(self, str storageName)
	cdef list[RecordNode] readBSTStorage(self, str storageName)
	cdef readAllData(self, BasicStorage storage)
	cdef checkPath(self)
	cdef str getResourcePath(self)