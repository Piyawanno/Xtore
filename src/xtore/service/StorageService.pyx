from re import T
from xtore.BaseType cimport i32

from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.test.People cimport People
from xtore.test.PeopleHashStorage cimport PeopleHashStorage

import os, sys, traceback, uuid

cdef bint IS_VENV = sys.prefix != sys.base_prefix

cdef class StorageService:
	def __init__(self, dict config):
		self.config = config

	cdef assignID(self, People record):
		record.ID = uuid.uuid4()

	cdef writeHashStorage(self, list[People] dataList):
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/People.{uuid.uuid4().int}.Hash.bin'
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleHashStorage storage = PeopleHashStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		io.open()
		try:
			if isNew: storage.create()
			else: storage.readHeader(0)
			self.writeData(storage, dataList)
			storage.writeHeader()
		except:
			print(traceback.format_exc())
		io.close()

	cdef writeData(self, BasicStorage storage, list[T] dataList):
		cdef i32 i = 0
		for data in dataList:
			storage.set(data)
			i += 1
			print(f'>> Recorded {i}: {data}')
		print(f"Success Recorded {i} Records !")
		
	cdef checkPath(self):
		cdef str resourcePath = self.getResourcePath()
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

	cdef str getResourcePath(self):
		if IS_VENV: return (f'{sys.prefix}/var/xtore').encode('utf-8').decode('utf-8')
		else: return '/var/xtore'