# Homomorphic People RecordNode

from xtore.BaseType cimport i16, i64, u64, f128, i32
from xtore.common.Buffer cimport Buffer, getBuffer, setBuffer, getBytes, setBytes, checkBufferSize
from xtore.instance.RecordNode cimport RecordNode
from xtore.instance.Homomorphic cimport Homomorphic

cdef i32 PEOPLE_ENTRY_KEY_SIZE = 8

cdef class EncryptedPeople (RecordNode):
	
	def __repr__(self):
		return f'<People ID={self.ID} income={self.income} name={self.name} {self.surname}>'

	cdef i64 hash(self):
		return <i64> self.ID

	cdef bint isEqual(self, RecordNode other):
		cdef EncryptedPeople otherPeople = <EncryptedPeople> other
		return self.ID == otherPeople.ID

	cdef readKey(self, i16 version, Buffer *stream):
		self.ID = (<i64*> getBuffer(stream, 8))[0]

	cdef readValue(self, i16 version, Buffer *stream):
		self.income = getBytes(stream)
		self.name = getBytes(stream)
		self.surname = getBytes(stream)

	cdef write(self, Buffer *stream):
		print("capacity :",stream.capacity)
		print("position :",stream.position)
		
		setBuffer(stream, <char *> &self.ID, 8)
		cdef i32 start = stream.position
		stream.position += 4

		print("len stream : ",len(self.income))
		print("capacity after resizeSize :",stream.capacity)

		checkBufferSize(stream, len(self.name))
		setBuffer(stream, <char *> self.name, len(self.name))
		checkBufferSize(stream, len(self.surname))
		setBuffer(stream, <char *> self.surname, len(self.surname))
		checkBufferSize(stream, len(self.income))
		setBuffer(stream, <char *> self.income, len(self.income))

		print("position :",stream.position)

		cdef i32 end = stream.position
		cdef i32 valueSize = end - start
		stream.position = start
		setBuffer(stream, <char *> &valueSize, 4)
		stream.position = end
		print("position :",stream.position)
		print("capacity :",stream.capacity)

# NOTE COMPARE
# - Deserialize
# - Homomorphic Compare
# - return result

	cdef i32 compare(self, RecordNode other):
		cdef EncryptedPeople otherPeople = <EncryptedPeople> other
		if self.ID == otherPeople.ID: return 0
		elif self.ID > otherPeople.ID: return 1
		else: return -1
	
	cdef f128 getRangeValue(self):
		return <f128> self.ID
