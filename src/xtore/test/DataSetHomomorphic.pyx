from xtore.BaseType cimport i32, i64
from xtore.common.Buffer cimport initBuffer, getBuffer, releaseBuffer
from xtore.common.StreamIOHandler cimport StreamIOHandler
from xtore.instance.HomomorphicBSTStorage cimport HomomorphicBSTStorage
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.CollisionMode cimport CollisionMode
from xtore.test.DataSet cimport DataSet, DATASET_ENTRY_KEY_SIZE

from libc.stdlib cimport malloc

cdef i32 BUFFER_SIZE = 1 << 13

cdef class DataSetHomomorphic(HomomorphicBSTStorage):
	def __init__(self, StreamIOHandler io):
		HomomorphicBSTStorage.__init__(self, io, CollisionMode.REPLACE)
		initBuffer(&self.entryStream, <char *> malloc(BUFFER_SIZE), BUFFER_SIZE)
		self.comparingNode = DataSet()
	
	def __dealloc__(self):
		releaseBuffer(&self.entryStream)
	
	cdef RecordNode createNode(self):
		return DataSet()

	cdef appendNode(self, RecordNode node):
		node.position = self.io.getTail()
		self.entryStream.position = 0
		node.write(&self.entryStream)
		self.io.append(&self.entryStream)

	cdef RecordNode readNodeKey(self, i64 position, RecordNode entry):
		if entry is None: entry = DataSet()
		entry.position = position
		self.io.seek(position)
		self.io.read(&self.entryStream, DATASET_ENTRY_KEY_SIZE)
		entry.readKey(0, &self.entryStream)
		self.readNodeValue(entry)
		return entry

	cdef readNodeValue(self, RecordNode node):
		cdef DataSet entry = <DataSet> node
		self.io.seek(node.position+DATASET_ENTRY_KEY_SIZE)
		self.io.read(&self.entryStream, 4)
		cdef i32 valueSize = (<i32 *> getBuffer(&self.entryStream, 4))[0]
		self.io.read(&self.entryStream, valueSize)
		entry.readValue(0, &self.entryStream)

	cdef writeNode(self, RecordNode node):
		cdef DataSet entry = <DataSet> node
		self.io.seek(node.position)
		self.entryStream.position = 0
		entry.write(&self.entryStream)
		self.io.write(&self.entryStream)