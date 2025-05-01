from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport Buffer, PyBytes_FromStringAndSize, getBuffer, initBuffer, releaseBuffer, setBuffer, setBytes

from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.common.ReplicaIOHandler cimport ReplicaIOHandler
from xtore.instance.BasicIterator cimport BasicIterator
from xtore.instance.HashIterator cimport HashIterator
from xtore.instance.RecordNode cimport RecordNode
from xtore.test.People cimport People
from xtore.test.PeopleBSTStorage cimport PeopleBSTStorage
from xtore.test.PeopleHashStorage cimport PeopleHashStorage
from xtore.instance.BinarySearchTreeStorage cimport BinarySearchTreeStorage

from libc.stdlib cimport malloc

import os, sys, traceback, uuid, asyncio

cdef bint IS_VENV = sys.prefix != sys.base_prefix

cdef i32 BUFFER_SIZE = 1 << 16
cdef i32 BST_NODE_OFFSET = 24

cdef class StorageHandler:
	def __init__(self, dict config):
		self.config = config
		initBuffer(&self.buffer, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		self.isFulled = 0
		self.maxCapacity = 5000
		self.currentUsage = 0

	def __dealloc__(self):
		releaseBuffer(&self.buffer)

	cdef assignID(self, People record):
		record.ID = uuid.uuid4()

	cdef BasicStorage openHashStorage(self, str fileName):
		cdef str resourcePath = self.getResourcePath()
		cdef str path = os.path.join(resourcePath, fileName)
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleHashStorage storage = PeopleHashStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		io.open()
		try:
			if isNew: storage.create()
			else: storage.readHeader(0)
		except:
			print(traceback.format_exc())
		return storage

	cdef BasicStorage openBSTStorage(self, str fileName):
		cdef str resourcePath = self.getResourcePath()
		os.makedirs(resourcePath, exist_ok=True)
		cdef str path = os.path.join(resourcePath, fileName)
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleBSTStorage storage = PeopleBSTStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		self.currentUsage = self.getFileSize(path)
		print(f"Usage:{self.currentUsage}")
		io.open()
		try:
			if isNew: storage.create()
			#elif self.currentUsage >= self.maxCapacity:
			#	self.isFulled = 1
			#	storage.readHeader(0)
			else: storage.readHeader(0)
		except:
			print(traceback.format_exc())
		return storage

	cdef i32 writeToStorage(self, list[RecordNode] dataList, BasicStorage storage):
		try:
			#if self.isFulled == 1:
			#	print(f"Node full")
			#	return 1
			self.writeData(storage, dataList)
			storage.writeHeader()
		except:
			print(traceback.format_exc())

	cdef writeData(self, BasicStorage storage, list[RecordNode] dataList):
		cdef i32 i = 0
		cdef i32 dataLength = len(dataList)
		cdef RecordNode node
		cdef bytes uuidBytes
		cdef i32 startPosition, endPosition
		cdef i32 recordSize = 0
		for data in range(dataLength):
			#if self.currentUsage >= self.maxCapacity:
			#	self.isFulled = 1
			#	print(f"Recorded Failed:Node fulled")
			#	break
			uuidBytes = uuid.uuid4().bytes[:8]
			self.buffer.position = 0
			setBuffer(&self.buffer, <char *> uuidBytes, 8)
			node = dataList[data]
			self.buffer.position = 0
			#node.write(&self.buffer)
			recordSize = self.buffer.position
			storage.set(node)
			self.currentUsage += recordSize
			print(self.currentUsage)
			print(node)
			i += 1
		print(f"Success Recorded {i} Records !")

	cdef readHashStorage(self, str storageName):
		cdef str resourcePath = self.getResourcePath()
		cdef str path = f'{resourcePath}/{storageName}.bin'
		print(f'storage path: {path}')
		cdef StreamIOHandler io = StreamIOHandler(path)
		cdef PeopleHashStorage storage = PeopleHashStorage(io)
		cdef bint isNew = not os.path.isfile(path)
		cdef list[RecordNode] nodeList = []
		cdef People entry = People()
		cdef int n = 0
		io.open()
		try:
			if isNew: print(f'Storage not found!')
			else: 
				storage.readHeader(0)
				for a in range(393000, 394231):
					try:
						node = storage.readNodeKey(a, None)
						storage.readNodeValue(node)
						print(f'a: {a}', end='\t')
						print(node)
					except:
						continue
				storage.readNodeValue(node)
				nodeList.append(node)
				print(node)
		except:
			print(traceback.format_exc())
		io.close()


	cdef list[RecordNode] readAllBSTStorage(self, BinarySearchTreeStorage storage):
		cdef int n = 0
		cdef i64 position
		cdef i64 nodePosition
		cdef i64 left
		cdef i64 right
		cdef list stack = []
		cdef list[RecordNode] nodeList = []
		cdef People node = People()

		try:
			storage.readHeader(0)
			position = storage.rootNodePosition
			while stack or position > 0:
				while position > 0:
					stack.append(position)
					storage.io.seek(position)
					storage.io.read(&storage.stream, BST_NODE_OFFSET)
					nodePosition = (<i64*> getBuffer(&storage.stream, 8))[0]
					left = (<i64*> getBuffer(&storage.stream, 8))[0]
					right = (<i64*> getBuffer(&storage.stream, 8))[0]
					position = left

				if len(stack) > 0:
					position = stack.pop()
					storage.io.seek(position)
					storage.io.read(&storage.stream, BST_NODE_OFFSET)
					nodePosition = (<i64*> getBuffer(&storage.stream, 8))[0]
					left = (<i64*> getBuffer(&storage.stream, 8))[0]
					right = (<i64*> getBuffer(&storage.stream, 8))[0]

					node = storage.readNodeKey(nodePosition, None)
					storage.readNodeValue(node)
					nodeList.append(node)

				position = right

			for record in nodeList:
				print(record)
		except:
			print(traceback.format_exc())
		return nodeList

	cdef list[RecordNode] readData(self, BasicStorage storage, list[RecordNode] queries):
		cdef list[RecordNode] queryResultList = []
		cdef RecordNode queryResult
		for query in queries:
			queryResult = storage.get(query, None)
			print(f">> Get {queryResult}")
			if queryResult is not None: queryResultList.append(queryResult)
		return queryResultList

	cdef readAllData(self, BasicStorage storage):
		pass
		
	cdef checkPath(self):
		cdef str resourcePath = self.getResourcePath()
		if not os.path.isdir(resourcePath): os.makedirs(resourcePath)

	cdef str getResourcePath(self):
		if IS_VENV: return (f'{sys.prefix}/var/xtore').encode('utf-8').decode('utf-8')
		else: return '/var/xtore'
	
	cdef i64 getFileSize(self, str path):
		try:
			return os.stat(path).st_size
		except:
			return -1