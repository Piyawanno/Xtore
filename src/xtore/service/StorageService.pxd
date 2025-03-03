from xtore.BaseType cimport i32
from xtore.common.Buffer cimport Buffer
from xtore.instance.BasicStorage cimport BasicStorage
from xtore.instance.RecordNode cimport RecordNode
from xtore.test.People cimport People
from xtore.instance.BinarySearchTreeStorage cimport BinarySearchTreeStorage

cdef class StorageService:
	cdef dict config
	cdef Buffer buffer

	cdef assignID(self, People record)
	cdef BasicStorage openHashStorage(self, str fileName)
	cdef BasicStorage openRTStorage(self, str fileName)
	cdef BasicStorage openBSTStorage(self, str fileName)
	cdef writeData(self, BasicStorage storage, list[RecordNode] data)
	cdef writeToStorage(self, list[RecordNode] dataList, BasicStorage storage)
	cdef readHashStorage(self, str storageName)
	cdef readRTStorage(self, str storageName)
	cdef list[RecordNode] readAllBSTStorage(self, BinarySearchTreeStorage storage)
	cdef readAllData(self, BasicStorage storage)
	cdef checkPath(self)
	cdef str getResourcePath(self)