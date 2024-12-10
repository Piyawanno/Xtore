from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport initBuffer, getBuffer, releaseBuffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.BinarySearchTreeStorage cimport BinarySearchTreeStorage
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.test.People cimport People, PEOPLE_ENTRY_KEY_SIZE

from libc.stdlib cimport malloc

cdef i32 BUFFER_SIZE = 1 << 16

cdef class PeopleBSTStorage(BinarySearchTreeStorage):
	def __init__(self, StreamIOHandler io):
		BinarySearchTreeStorage.__init__(self, io, CollisionMode.REPLACE)
		initBuffer(&self.entryStream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		self.comparingNode = People()
	
	def __dealloc__(self):
		releaseBuffer(&self.entryStream)
	
	cdef RecordNode createNode(self):
		return People()
		
	cdef appendNode(self, RecordNode node):
		node.position = self.io.getTail()
		self.entryStream.position = 0
		node.write(&self.entryStream)
		self.io.append(&self.entryStream)

	cdef RecordNode readNodeKey(self, i64 position, RecordNode entry):
		if entry is None: entry = People()
		entry.position = position
		self.io.seek(position)
		self.io.read(&self.entryStream, PEOPLE_ENTRY_KEY_SIZE)
		entry.readKey(0, &self.entryStream)
		return entry
	
	cdef readNodeValue(self, RecordNode node):
		cdef People entry = <People> node
		self.io.seek(node.position+PEOPLE_ENTRY_KEY_SIZE)
		self.io.read(&self.entryStream, 4)
		cdef i32 valueSize = (<i32 *> getBuffer(&self.entryStream, 4))[0]
		self.io.read(&self.entryStream, valueSize)
		entry.readValue(0, &self.entryStream)
	
	cdef writeNode(self, RecordNode node):
		cdef People entry = <People> node
		self.io.seek(node.position)
		self.entryStream.position = 0
		entry.write(&self.entryStream)
		self.io.write(&self.entryStream)