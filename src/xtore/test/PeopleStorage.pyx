from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport initBuffer, getBuffer, releaseBuffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.HashStorage cimport HashStorage
from xtore.instance.HashNode cimport HashNode
from xtore.test.People cimport People, PEOPLE_ENTRY_KEY_SIZE

from libc.stdlib cimport malloc

cdef i32 BUFFER_SIZE = 1 << 16
cdef class PeopleStorage(HashStorage):
	def __init__(self, StreamIOHandler io):
		HashStorage.__init__(self, io)
		initBuffer(&self.entryStream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		self.comparingNode = People()
	
	def __dealloc__(self):
		return
		releaseBuffer(&self.entryStream)
		
	cdef appendNode(self, HashNode node):
		node.position = self.io.getTail()
		self.entryStream.position = 0
		node.write(&self.entryStream)
		self.io.append(&self.entryStream)

	cdef HashNode readNodeKey(self, i64 position, HashNode entry):
		if entry is None: entry = People()
		entry.position = position
		self.io.seek(position)
		self.io.read(&self.entryStream, PEOPLE_ENTRY_KEY_SIZE)
		entry.readKey(0, &self.entryStream)
		return entry
	
	cdef readNodeValue(self, HashNode node):
		cdef People entry = <People> node
		self.io.seek(node.position+PEOPLE_ENTRY_KEY_SIZE)
		self.io.read(&self.entryStream, 4)
		cdef i32 valueSize = (<i32 *> getBuffer(&self.entryStream, 4))[0]
		self.io.read(&self.entryStream, valueSize)
		entry.readValue(0, &self.entryStream)
	
	cdef writeNode(self, HashNode node):
		cdef People entry = <People> node
		self.io.seek(node.position)
		self.entryStream.position = 0
		entry.write(&self.entryStream)
		self.io.write(&self.entryStream)
	